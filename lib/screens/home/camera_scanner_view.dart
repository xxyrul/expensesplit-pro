import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

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
    FlashMode.auto,
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
  /// At ~1 frame per 400 ms → 4 frames ≈ 1.6 s.
  static const int _stableFrameThreshold = 4;

  /// Minimum number of text blocks to even start the stable counter.
  static const int _minBlocksToConsider = 2;

  // ── Overlay animation ────────────────────────────────────────────────────────
  late AnimationController _cornerAnimCtrl;
  late Animation<Color?> _cornerColorAnim;
  bool _textDetectedLastFrame = false;

  // ── Capture result ────────────────────────────────────────────────────────────
  XFile? _capturedFile;

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
      end: const Color(0xFF0F766E),
    ).animate(CurvedAnimation(parent: _cornerAnimCtrl, curve: Curves.easeOut));

    _initCamera();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _cornerAnimCtrl.dispose();
    _controller?.stopImageStream();
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Camera init
  // ─────────────────────────────────────────────────────────────────────────────

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
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      if (!mounted) return;

      await _controller!.setFlashMode(_flashMode);
      await _controller!.startImageStream(_onImageAvailable);

      setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Live frame processing
  // ─────────────────────────────────────────────────────────────────────────────

  /// Throttle: one frame every 400 ms.
  DateTime _lastProcessedAt = DateTime(0);

  void _onImageAvailable(CameraImage image) {
    if (_isProcessingFrame || _isCapturing) return;

    final now = DateTime.now();
    if (now.difference(_lastProcessedAt).inMilliseconds < 400) return;
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
      await _controller!.stopImageStream();
      final XFile file = await _controller!.takePicture();
      _capturedFile = file;

      if (!mounted) return;
      await _navigateToConfirm(file);
    } catch (e) {
      debugPrint('Capture error: $e');
    } finally {
      _isCapturing = false;
      _stableFrameCount = 0;
      if (mounted) setState(() => _captureProgress = 0.0);
      // Restart stream after returning (the navigator pop re-mounts this page).
    }
  }

  Future<void> _navigateToConfirm(XFile imageFile) async {
    // Parse synchronously so we can pass pre-filled data.
    final scanner = ReceiptScannerService();
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final recognized = await _textRecognizer.processImage(inputImage);
    final parsed = scanner.parseReceiptText(
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
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    await _navigateToConfirm(file);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
              child: CircularProgressIndicator(color: Color(0xFF0F766E)),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _CircleButton(
              icon: Icons.close_rounded,
              onTap: () => Navigator.maybePop(context),
            ),
            const Text(
              'Scan Receipt',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 40), // balance the close button
          ],
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
        ? const Color(0xFF0F766E)
        : textSeen
        ? const Color(0xFF0F766E).withOpacity(0.85)
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
        ..color = const Color(0xFF0F766E).withOpacity(0.85)
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
              ? const Color(0xFF0F766E).withOpacity(0.9)
              : Colors.white.withOpacity(0.18),
          shape: BoxShape.circle,
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
                Color(0xFF0F766E),
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
              color: isCapturing ? const Color(0xFF0F766E) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF0F766E,
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
                    color: Color(0xFF134E4A),
                    size: 30,
                  ),
          ),
        ],
      ),
    );
  }
}
