import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/receipt_scanner_service.dart';
import 'add_expense_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

class CameraScannerView extends StatefulWidget {
  const CameraScannerView({super.key});

  @override
  State<CameraScannerView> createState() => _CameraScannerViewState();
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class _CameraScannerViewState extends State<CameraScannerView>
    with TickerProviderStateMixin {
  // ── Camera ──────────────────────────────────────────────────────────────────
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady = false;

  // ── Flash ────────────────────────────────────────────────────────────────────
  FlashMode _flashMode = FlashMode.off;
  final List<FlashMode> _flashCycle = [
    FlashMode.off,
    FlashMode.torch,
  ];

  // ── ML Kit ──────────────────────────────────────────────────────────────────
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  bool _isProcessingFrame = false;
  bool _isCapturing = false;

  // ── Stable-frame detection ───────────────────────────────────────────────────
  /// Number of recognised text blocks in the last stable frame.
  int _lastBlockCount = 0;

  /// Rough hash of detected text so we can detect change.
  String _lastTextHash = '';

  /// How many consecutive frames saw the same text.
  int _stableFrameCount = 0;

  /// Frames that must be stable before auto-capture fires.
  /// At ~1 frame per 800 ms → 2 frames ≈ 1.6 s.
  static const int _stableFrameThreshold = 2;

  /// Minimum number of text blocks to even start the stable counter.
  static const int _minBlocksToConsider = 2;

  // ── Overlay animation ────────────────────────────────────────────────────────
  late AnimationController _cornerAnimCtrl;
  late Animation<Color?> _cornerColorAnim;
  bool _textDetectedLastFrame = false;

  // ── Permission ────────────────────────────────────────────────────────────────
  bool _hasCameraPermission = false;
  bool _permissionChecked = false;

  // ── Countdown display ────────────────────────────────────────────────────────
  double _captureProgress = 0.0; // 0.0 → 1.0 as stable frames accumulate

  // ─────────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _cornerAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cornerColorAnim = ColorTween(
      begin: Colors.white,
      end: const Color(0xFF115E59),
    ).animate(CurvedAnimation(parent: _cornerAnimCtrl, curve: Curves.easeOut));

    _requestCameraPermission();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _cornerAnimCtrl.dispose();
    try {
      _controller?.stopImageStream();
    } catch (_) {}
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Camera init
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _hasCameraPermission = status.isGranted;
      _permissionChecked = true;
    });
    if (status.isGranted) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: !kIsWeb && Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      if (!mounted) return;

      // ── Flash: always start with flash off ──────────────────────────────────
      await _controller!.setFlashMode(FlashMode.off);

      // ── Autofocus: enable continuous AF + lock exposure to centre ──────────
      await _applyFocusSettings();

      await _controller!.startImageStream(_onImageAvailable);

      setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  /// Applies stable continuous autofocus and auto-exposure centred on frame.
  /// Silently ignores errors on devices that don't support these APIs.
  Future<void> _applyFocusSettings() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    try {
      // Continuous autofocus (re-focuses whenever the scene changes).
      await ctrl.setFocusMode(FocusMode.auto);
    } catch (_) {}
    try {
      // Pin the focus-point to the very centre of the viewfinder.
      await ctrl.setFocusPoint(const Offset(0.5, 0.5));
    } catch (_) {}
    try {
      await ctrl.setExposureMode(ExposureMode.auto);
    } catch (_) {}
    try {
      await ctrl.setExposurePoint(const Offset(0.5, 0.5));
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Live frame processing
  // ─────────────────────────────────────────────────────────────────────────────

  /// Throttle: one frame every 800 ms.
  DateTime _lastProcessedAt = DateTime(0);

  void _onImageAvailable(CameraImage image) {
    if (_isProcessingFrame || _isCapturing) return;

    final now = DateTime.now();
    if (now.difference(_lastProcessedAt).inMilliseconds < 800) return;
    _lastProcessedAt = now;

    _isProcessingFrame = true;
    _recognizeTextFromStream(image).whenComplete(() {
      _isProcessingFrame = false;
    });
  }

  Future<void> _recognizeTextFromStream(CameraImage image) async {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final imageSize = Size(image.width.toDouble(), image.height.toDouble());

      final camera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final imageRotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
          InputImageRotation.rotation0deg;

      final inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );

      final RecognizedText result = await _textRecognizer.processImage(
        inputImage,
      );

      if (!mounted) return;

      final blockCount = result.blocks.length;
      final textHash = result.text.trim();
      final hasText = blockCount >= _minBlocksToConsider;

      // ── Update corner animation ──────────────────────────────────────────────
      if (hasText && !_textDetectedLastFrame) {
        _cornerAnimCtrl.forward();
      } else if (!hasText && _textDetectedLastFrame) {
        _cornerAnimCtrl.reverse();
        _stableFrameCount = 0;
        _lastTextHash = '';
        _lastBlockCount = 0;
        if (mounted) setState(() => _captureProgress = 0.0);
      }
      _textDetectedLastFrame = hasText;

      // ── Stable-frame check ───────────────────────────────────────────────────
      if (hasText) {
        if (textHash == _lastTextHash && blockCount == _lastBlockCount) {
          _stableFrameCount++;
        } else {
          _stableFrameCount = 1;
          _lastTextHash = textHash;
          _lastBlockCount = blockCount;
        }

        final progress = (_stableFrameCount / _stableFrameThreshold).clamp(
          0.0,
          1.0,
        );
        if (mounted) setState(() => _captureProgress = progress);

        if (_stableFrameCount >= _stableFrameThreshold && !_isCapturing) {
          _triggerCapture();
        }
      }
    } catch (_) {
      // Ignore per-frame errors silently.
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Capture
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _triggerCapture() async {
    if (_isCapturing || _controller == null || !_isCameraReady) return;
    _isCapturing = true;

    try {
      try {
        await _controller!.setFlashMode(_flashMode);
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 200));

      final XFile file = await _controller!.takePicture();

      // HACK: Samsung and some other Android devices have a bug where the flash
      // stays permanently stuck ON after takePicture() if it was used.
      // The proven workaround is to briefly force it to Torch, then Off.
      try {
        await _controller!.setFlashMode(FlashMode.torch);
        await Future.delayed(const Duration(milliseconds: 50));
        await _controller!.setFlashMode(FlashMode.off);
      } catch (_) {}

      if (!mounted) return;
      await _navigateToConfirm(file);
    } catch (e) {
      debugPrint('Capture error: $e');
    } finally {
      _isCapturing = false;
      _stableFrameCount = 0;
      if (mounted) setState(() => _captureProgress = 0.0);
    }
  }

  Future<void> _navigateToConfirm(XFile imageFile) async {
    // Parse synchronously so we can pass pre-filled data.
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final recognized = await _textRecognizer.processImage(inputImage);
    final parsed = ReceiptScannerService.parseReceiptText(
      ReceiptScannerService.formatRecognizedText(recognized),
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => AddExpenseScreen(
          capturedImagePath: imageFile.path,
          initialAmount: parsed['amount'],
          initialVendor: parsed['vendor'],
          initialDate: parsed['date'],
          rawText: parsed['rawText'],
          showScanSuccessBanner: true,
          needsReview: parsed['needsReview'] ?? false,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );

    // Restart stream on return.
    if (mounted && _controller != null && _controller!.value.isInitialized) {
      _isCapturing = false;
      _stableFrameCount = 0;
      _lastTextHash = '';
      _textDetectedLastFrame = false;
      _cornerAnimCtrl.reverse();
      setState(() => _captureProgress = 0.0);

      // Restore the user's flash preference and re-apply stable AF/AE
      // now that we are back in live-preview mode.
      try {
        await _controller!.setFlashMode(_flashMode);
      } catch (_) {}
      await _applyFocusSettings();

      await _controller!.startImageStream(_onImageAvailable);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Flash toggle
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _toggleFlash() async {
    final idx = (_flashCycle.indexOf(_flashMode) + 1) % _flashCycle.length;
    final next = _flashCycle[idx];
    try {
      await _controller?.setFlashMode(next);
      if (mounted) setState(() => _flashMode = next);
    } catch (_) {}
  }

  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.torch:
        return Icons.flash_on_rounded;
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      default:
        return Icons.flash_off_rounded;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Gallery pick
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    // Stop stream before opening gallery to avoid 'already streaming' error
    try {
      await _controller?.stopImageStream();
    } catch (_) {}

    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null || !mounted) {
      // Restart stream if user cancelled
      if (mounted &&
          _controller != null &&
          _controller!.value.isInitialized) {
        await _controller!.startImageStream(_onImageAvailable);
      }
      return;
    }

    await _navigateToConfirm(file);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Show permission denied UI if camera access was not granted
    if (_permissionChecked && !_hasCameraPermission) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt_rounded,
                      size: 80, color: Color(0xFF115E59)),
                  const SizedBox(height: 24),
                  const Text(
                    'Camera Access Required',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'To scan receipts, ExpenseSplit Pro needs access to your camera. Please enable it in your device settings.',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await openAppSettings();
                    },
                    icon: const Icon(Icons.settings_rounded),
                    label: const Text('Open Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF115E59),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back',
                        style: TextStyle(color: Colors.white54)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ───────────────────────────────────────────────────
          if (_isCameraReady && _controller != null)
            CameraPreview(_controller!)
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF115E59)),
            ),

          // ── Scanning overlay ─────────────────────────────────────────────────
          if (_isCameraReady)
            AnimatedBuilder(
              animation: _cornerColorAnim,
              builder: (_, __) => CustomPaint(
                painter: _ScannerOverlayPainter(
                  frameColor: _cornerColorAnim.value ?? Colors.white,
                  progress: _captureProgress,
                ),
              ),
            ),

          // ── Top bar ────────────────────────────────────────────────────────
          _buildTopBar(),

          // ── Bottom control row ───────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomControls(),
          ),

          // ── Status pill ──────────────────────────────────────────────────────
          if (_isCameraReady)
            Positioned(
              left: 0,
              right: 0,
              bottom: 160,
              child: _buildStatusPill(),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Sub-widgets
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.4), Colors.transparent],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CircleButton(
                icon: Icons.close_rounded,
                size: 40,
                iconSize: 22,
                onTap: () => Navigator.maybePop(context),
              ),
              const Text(
                'Scan Receipt',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: EdgeInsets.only(
        left: 32,
        right: 32,
        top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.85), Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Gallery
          _CircleButton(
            icon: Icons.photo_library_outlined,
            size: 50,
            iconSize: 24,
            onTap: _pickFromGallery,
          ),

          // Shutter
          _ShutterButton(
            isCapturing: _isCapturing,
            progress: _captureProgress,
            onTap: _triggerCapture,
          ),

          // Flash
          _CircleButton(
            icon: _flashIcon,
            size: 50,
            iconSize: 24,
            onTap: _toggleFlash,
            highlighted: _flashMode != FlashMode.off,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill() {
    final bool textSeen = _textDetectedLastFrame;
    final String label = _isCapturing
        ? 'Capturing…'
        : textSeen
        ? _captureProgress >= 0.99
              ? 'Locking on…'
              : 'Receipt detected — hold steady'
        : 'Point camera at a receipt';

    final Color pillColor = _isCapturing
        ? const Color(0xFF115E59)
        : textSeen
        ? const Color(0xFF115E59).withOpacity(0.85)
        : Colors.black54;

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: pillColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (textSeen) ...[
              const Icon(
                Icons.text_fields_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overlay Painter
// ─────────────────────────────────────────────────────────────────────────────

class _ScannerOverlayPainter extends CustomPainter {
  final Color frameColor;
  final double progress; // 0–1, drives the progress arc on shutter

  const _ScannerOverlayPainter({
    required this.frameColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Frame dimensions: tall portrait frame sized to fit a full receipt.
    // Height-driven so it stays proportional on all screen sizes.
    final double frameH = size.height * 0.72;
    final double frameW = size.width * 0.88;
    final double left = (size.width - frameW) / 2;
    final double top = (size.height - frameH) / 2 - size.height * 0.02;
    final frameRect = Rect.fromLTWH(left, top, frameW, frameH);
    final frameRRect = RRect.fromRectAndRadius(
      frameRect,
      const Radius.circular(16),
    );

    // ── Dark overlay with cutout ──────────────────────────────────────────────
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.55);
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(frameRRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlayPath, overlayPaint);

    // ── Frame border (thin, always white) ─────────────────────────────────────
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(frameRRect, borderPaint);

    // ── Corner accents ────────────────────────────────────────────────────────
    final cornerPaint = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final double cLen = min(frameW, frameH) * 0.18;
    final double r = 16.0;

    void drawCorner(Offset origin, double dx, double dy) {
      // Horizontal arm
      final double hx1 = origin.dx + (dx > 0 ? r : -r);
      final double hx2 = hx1 + dx * cLen;
      canvas.drawLine(
        Offset(hx1, origin.dy),
        Offset(hx2, origin.dy),
        cornerPaint,
      );

      // Vertical arm
      final double vy1 = origin.dy + (dy > 0 ? r : -r);
      final double vy2 = vy1 + dy * cLen;
      canvas.drawLine(
        Offset(origin.dx, vy1),
        Offset(origin.dx, vy2),
        cornerPaint,
      );
    }

    // Top-left
    drawCorner(Offset(frameRect.left, frameRect.top), 1, 1);
    // Top-right
    drawCorner(Offset(frameRect.right, frameRect.top), -1, 1);
    // Bottom-left
    drawCorner(Offset(frameRect.left, frameRect.bottom), 1, -1);
    // Bottom-right
    drawCorner(Offset(frameRect.right, frameRect.bottom), -1, -1);

    // ── Progress sweep at top edge of frame ────────────────────────────────────
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = const Color(0xFF115E59).withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      final sweepW = frameW * progress;
      final startX = frameRect.left + (frameW - sweepW) / 2;
      canvas.drawLine(
        Offset(startX, frameRect.top),
        Offset(startX + sweepW, frameRect.top),
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScannerOverlayPainter old) =>
      old.frameColor != frameColor || old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final bool highlighted;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.iconSize = 20,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: highlighted
              ? const Color(0xFF115E59).withOpacity(0.9)
              : Colors.black.withOpacity(0.3),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final bool isCapturing;
  final double progress;
  final VoidCallback onTap;

  const _ShutterButton({
    required this.isCapturing,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isCapturing ? null : onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress ring
          SizedBox(
            width: 84,
            height: 84,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF115E59),
              ),
            ),
          ),
          // Inner circle
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCapturing ? const Color(0xFF115E59) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF115E59,
                  ).withOpacity(isCapturing ? 0.6 : 0.0),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: isCapturing
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                : const Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFF042F2E),
                    size: 30,
                  ),
          ),
        ],
      ),
    );
  }
}
