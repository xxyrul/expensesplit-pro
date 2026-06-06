import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/receipt_scanner_service.dart';
import 'add_expense_screen.dart';

const Color luminaPrimary = Color(0xFFC0C1FF);
const Color luminaGlow = Color(0xFF8083FF);

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

class CameraScannerView extends StatefulWidget {
  final bool returnImageOnly;

  const CameraScannerView({super.key, this.returnImageOnly = false});

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
    FlashMode.always,
  ];

  // ── ML Kit ──────────────────────────────────────────────────────────────────
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  bool _isProcessingFrame = false;
  bool _isCapturing = false;

  // ── Live Data ───────────────────────────────────────────────────────────────
  String? _liveMerchant;
  String? _liveAmount;

  // ── Stable-frame detection ───────────────────────────────────────────────────
  int _lastBlockCount = 0;
  String _lastTextHash = '';
  int _stableFrameCount = 0;
  static const int _stableFrameThreshold = 2;
  static const int _minBlocksToConsider = 2;

  // ── Overlay animation ────────────────────────────────────────────────────────
  late AnimationController _cornerAnimCtrl;
  late Animation<Color?> _cornerColorAnim;
  late AnimationController _scanLineAnimCtrl;
  bool _textDetectedLastFrame = false;

  // ── Permission ────────────────────────────────────────────────────────────────
  bool _hasCameraPermission = false;
  bool _permissionChecked = false;

  // ── Countdown display ────────────────────────────────────────────────────────
  double _captureProgress = 0.0;

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
      end: luminaPrimary,
    ).animate(CurvedAnimation(parent: _cornerAnimCtrl, curve: Curves.easeOut));

    _scanLineAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Initialize camera immediately instead of waiting 400ms
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _requestCameraPermission();
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _cornerAnimCtrl.dispose();
    _scanLineAnimCtrl.dispose();
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
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: !kIsWeb && Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      if (!mounted) return;

      // ── Flash: always start with flash off ──────────────────────────────────
      await _controller!.setFlashMode(FlashMode.off);

      // ── Autofocus ──────────
      await _applyFocusSettings();

      await _controller!.startImageStream(_onImageAvailable);

      setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _applyFocusSettings() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    try {
      await ctrl.setFocusMode(FocusMode.auto);
    } catch (_) {}
    try {
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

      if (hasText) {
        final lines = result.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
        if (lines.isNotEmpty) {
          if (mounted) setState(() => _liveMerchant = lines.first);
        }
        final amountRegex = RegExp(r'(?:TOTAL|GRAND TOTAL|AMOUNT DUE|JUMLAH|BAYARAN)[:\s]*(?:RM)?\s*(\d+\.\d{2})', caseSensitive: false);
        final matches = amountRegex.allMatches(result.text);
        if (matches.isNotEmpty) {
          if (mounted) setState(() => _liveAmount = 'RM ${matches.last.group(1)}');
        }

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
      } else {
        if (mounted) {
          setState(() {
            _liveMerchant = null;
            _liveAmount = null;
          });
        }
      }

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
      // Stop the live stream first to avoid conflicts
      try {
        await _controller!.stopImageStream();
      } catch (_) {}

      // Set flash mode for the capture
      try {
        await _controller!.setFlashMode(_flashMode);
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 200));

      final XFile file = await _controller!.takePicture();

      // Reset flash to off after capture to avoid stuck flash
      try {
        await _controller!.setFlashMode(FlashMode.off);
      } catch (_) {}

      if (!mounted) return;
      if (widget.returnImageOnly) {
        Navigator.of(context).pop(file.path);
        return;
      }
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
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: luminaPrimary.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: luminaPrimary.withOpacity(0.1),
                blurRadius: 30,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  color: luminaPrimary,
                  strokeWidth: 3,
                  backgroundColor: Colors.white.withOpacity(0.08),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Scanning receipt with AI…',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This may take a few seconds',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    final inputImage = InputImage.fromFilePath(imageFile.path);
    final recognized = await _textRecognizer.processImage(inputImage);
    final rawText = ReceiptScannerService.formatRecognizedText(recognized);
    
    final parsed = await ReceiptScannerService.analyzeTextWithAI(rawText);

    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss loading

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          capturedImagePath: imageFile.path,
          initialAmount: parsed?['amount'],
          initialVendor: parsed?['vendor'],
          initialDate: parsed?['date'],
          rawText: parsed?['rawText'],
          showScanSuccessBanner: true,
          needsReview: parsed?['needsReview'] ?? false,
        ),
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

      try {
        await _controller!.setFlashMode(FlashMode.off);
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
    if (mounted) setState(() => _flashMode = next);
  }

  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.always:
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
    try {
      await _controller?.stopImageStream();
    } catch (_) {}

    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (file == null || !mounted) {
      if (mounted &&
          _controller != null &&
          _controller!.value.isInitialized) {
        await _controller!.startImageStream(_onImageAvailable);
      }
      return;
    }

    if (widget.returnImageOnly) {
      Navigator.of(context).pop(file.path);
      return;
    }
    await _navigateToConfirm(file);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ── Permission denied ────────────────────────────────────────────────────
    if (_permissionChecked && !_hasCameraPermission) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(36.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          luminaPrimary.withOpacity(0.25),
                          luminaPrimary.withOpacity(0.08),
                        ],
                      ),
                      border: Border.all(
                        color: luminaPrimary.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 44,
                      color: luminaPrimary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Camera Access Required',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'To scan receipts, ExpenseSplit Pro needs access to your camera. Please enable it in your device settings.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 15,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  GestureDetector(
                    onTap: () async => await openAppSettings(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [luminaPrimary, luminaGlow],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: luminaPrimary.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.settings_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Open Settings',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Go Back',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── Main scanner screen ──────────────────────────────────────────────────
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ─────────────────────────────────────────────────
          if (_isCameraReady && _controller != null)
            CameraPreview(_controller!)
          else
            Container(
              color: const Color(0xFF0A0A0A),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        color: luminaPrimary,
                        strokeWidth: 2.5,
                        backgroundColor: Colors.white.withOpacity(0.06),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Initializing camera...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Scanning overlay ───────────────────────────────────────────────
          if (_isCameraReady)
            AnimatedBuilder(
              animation: Listenable.merge([_cornerColorAnim, _scanLineAnimCtrl]),
              builder: (_, __) => IgnorePointer(
                child: CustomPaint(
                  painter: _ScannerOverlayPainter(
                    frameColor: _cornerColorAnim.value ?? Colors.white,
                    progress: _captureProgress,
                    scanLinePosition: _scanLineAnimCtrl.value,
                  ),
                ),
              ),
            ),

          // ── Gesture Detector for Focus ─────────────────────────────────────
          if (_isCameraReady)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (details) async {
                  final ctrl = _controller;
                  if (ctrl == null || !ctrl.value.isInitialized) return;
                  try {
                    final Size size = MediaQuery.of(context).size;
                    final double x = details.localPosition.dx / size.width;
                    final double y = details.localPosition.dy / size.height;
                    await ctrl.setFocusPoint(Offset(x, y));
                    await ctrl.setExposurePoint(Offset(x, y));
                  } catch (_) {}
                },
              ),
            ),

          // ── Status pill ────────────────────────────────────────────────────
          if (_isCameraReady)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).size.height * 0.35,
              child: _buildStatusPill(),
            ),

          // ── Data Preview Card ──────────────────────────────────────────────
          if (_isCameraReady)
            Positioned(
              left: 0,
              right: 0,
              bottom: 140,
              child: _buildDataPreviewCard(),
            ),

          // ── Bottom controls (pinned) ───────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomControls(),
          ),

          // ── Top bar (pinned) ───────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(),
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
          colors: [
            Colors.black.withOpacity(0.70),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: back button
              _GlassCircleButton(
                icon: Icons.close_rounded,
                size: 42,
                iconSize: 20,
                onTap: () => Navigator.maybePop(context),
              ),
              // Right: flash toggle
              _GlassCircleButton(
                icon: _flashIcon,
                size: 42,
                iconSize: 20,
                onTap: _toggleFlash,
                highlighted: _flashMode != FlashMode.off,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill() {
    final bool textSeen = _textDetectedLastFrame;
    final String label = _isCapturing
        ? 'CAPTURING...'
        : textSeen
            ? _captureProgress >= 0.99
                ? 'LOCKING ON...'
                : 'RECEIPT DETECTED...'
            : 'AUTO-DETECTING RECEIPT...';

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: textSeen ? luminaPrimary.withOpacity(0.5) : Colors.transparent,
            width: 1,
          ),
          boxShadow: textSeen
              ? [
                  BoxShadow(
                    color: luminaGlow.withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: luminaPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildDataPreviewCard() {
    final bool show = _textDetectedLastFrame || _liveMerchant != null || _liveAmount != null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: show ? 1.0 : 0.0,
      child: IgnorePointer(
        ignoring: !show,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: luminaPrimary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: luminaGlow,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'MERCHANT',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _liveMerchant ?? 'Scanning...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ESTIMATED',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _liveAmount ?? '...',
                          style: const TextStyle(
                            color: luminaPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF201F22).withOpacity(0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Gallery button
                  _GlassCircleButton(
                    icon: Icons.photo_library_outlined,
                    size: 52,
                    iconSize: 24,
                    onTap: _pickFromGallery,
                  ),
                  // Premium shutter button
                  _PremiumShutterButton(
                    isCapturing: _isCapturing,
                    progress: _captureProgress,
                    onTap: _triggerCapture,
                  ),
                  // Spacer to balance the layout since the tune button was removed
                  const SizedBox(width: 52),
                ],
              ),
            ),
          ),
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
  final double progress;
  final double scanLinePosition;

  const _ScannerOverlayPainter({
    required this.frameColor,
    required this.progress,
    required this.scanLinePosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── Frame dimensions ────────────────────────────────────────────────────
    final double frameH = size.height * 0.55;
    final double frameW = size.width * 0.85;
    final double left = (size.width - frameW) / 2;
    final double top = (size.height - frameH) / 2 - size.height * 0.03;
    final frameRect = Rect.fromLTWH(left, top, frameW, frameH);
    final frameRRect = RRect.fromRectAndRadius(
      frameRect,
      const Radius.circular(20),
    );

    // ── Dark overlay with cutout (0.65 opacity) ─────────────────────────────
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.65);
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(frameRRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlayPath, overlayPaint);

    // ── Subtle thin white border (0.12 opacity) ─────────────────────────────
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(frameRRect, borderPaint);

    // ── Corner brackets ─────────────────────────────────────────────────────
    final bool hasGlow = frameColor != Colors.white;
    final double cLen = min(frameW, frameH) * 0.12;
    const double r = 20.0;

    // Glow behind corners when text detected
    if (hasGlow) {
      final glowPaint = Paint()
        ..color = luminaGlow.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

      _drawCornerBrackets(canvas, frameRect, cLen, r, glowPaint);
    }

    // Solid corner brackets
    final cornerPaint = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    _drawCornerBrackets(canvas, frameRect, cLen, r, cornerPaint);

    // ── Sweeping Line ───────────────────────────────────────────────────────
    final lineY = frameRect.top + (frameRect.height * scanLinePosition);
    final scanLinePaint = Paint()
      ..color = luminaPrimary.withOpacity(0.4)
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      
    final scanLineGradient = LinearGradient(
      colors: [
        luminaPrimary.withOpacity(0.0),
        luminaPrimary.withOpacity(0.8),
        luminaPrimary.withOpacity(0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(frameRect.left, lineY, frameRect.width, 2));

    final scanLineGradientPaint = Paint()
      ..shader = scanLineGradient
      ..strokeWidth = 2.0;

    canvas.drawLine(
      Offset(frameRect.left, lineY),
      Offset(frameRect.right, lineY),
      scanLinePaint,
    );
    canvas.drawLine(
      Offset(frameRect.left, lineY),
      Offset(frameRect.right, lineY),
      scanLineGradientPaint,
    );

    // ── Progress sweep: top AND bottom edges ────────────────────────────────
    if (progress > 0) {
      final sweepW = frameW * progress;
      final startX = frameRect.left + (frameW - sweepW) / 2;

      final progressPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            luminaPrimary.withOpacity(0.0),
            luminaPrimary,
            luminaPrimary,
            luminaPrimary.withOpacity(0.0),
          ],
          stops: const [0.0, 0.15, 0.85, 1.0],
        ).createShader(Rect.fromLTWH(startX, 0, sweepW, 1))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      // Top edge
      canvas.drawLine(
        Offset(startX, frameRect.top),
        Offset(startX + sweepW, frameRect.top),
        progressPaint,
      );

      // Bottom edge
      canvas.drawLine(
        Offset(startX, frameRect.bottom),
        Offset(startX + sweepW, frameRect.bottom),
        progressPaint,
      );
    }
  }

  void _drawCornerBrackets(
    Canvas canvas,
    Rect frameRect,
    double cLen,
    double r,
    Paint paint,
  ) {
    void drawCorner(Offset origin, double dx, double dy) {
      // Horizontal arm
      final double hx1 = origin.dx + (dx > 0 ? r : -r);
      final double hx2 = hx1 + dx * cLen;
      canvas.drawLine(
        Offset(hx1, origin.dy),
        Offset(hx2, origin.dy),
        paint,
      );
      // Vertical arm
      final double vy1 = origin.dy + (dy > 0 ? r : -r);
      final double vy2 = vy1 + dy * cLen;
      canvas.drawLine(
        Offset(origin.dx, vy1),
        Offset(origin.dx, vy2),
        paint,
      );
    }

    drawCorner(Offset(frameRect.left, frameRect.top), 1, 1);
    drawCorner(Offset(frameRect.right, frameRect.top), -1, 1);
    drawCorner(Offset(frameRect.left, frameRect.bottom), 1, -1);
    drawCorner(Offset(frameRect.right, frameRect.bottom), -1, -1);
  }

  @override
  bool shouldRepaint(_ScannerOverlayPainter old) =>
      old.frameColor != frameColor || 
      old.progress != progress ||
      old.scanLinePosition != scanLinePosition;
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass Circle Button
// ─────────────────────────────────────────────────────────────────────────────

class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final bool highlighted;

  const _GlassCircleButton({
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
              ? luminaPrimary.withOpacity(0.25)
              : Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: highlighted
                ? luminaPrimary.withOpacity(0.6)
                : Colors.white.withOpacity(0.12),
            width: 1,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Shutter Button
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumShutterButton extends StatelessWidget {
  final bool isCapturing;
  final double progress;
  final VoidCallback onTap;

  const _PremiumShutterButton({
    required this.isCapturing,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isCapturing ? null : onTap,
      child: SizedBox(
        width: 80,
        height: 80,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer progress ring
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 3,
                backgroundColor: Colors.white.withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  luminaPrimary,
                ),
              ),
            ),
            // White ring (3px border, 68x68)
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.9),
                  width: 3,
                ),
              ),
            ),
            // Inner fill: animates between white circle and red rounded rect
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: isCapturing ? 28 : 56,
              height: isCapturing ? 28 : 56,
              decoration: BoxDecoration(
                color: isCapturing
                    ? const Color(0xFFEF4444)
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(
                  isCapturing ? 8 : 28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
