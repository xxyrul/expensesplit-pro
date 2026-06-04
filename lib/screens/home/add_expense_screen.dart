import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/expense_model.dart';
import '../../services/expense_service.dart';
import '../../providers/expense_providers.dart';
import '../../services/vendor_intelligence_service.dart';
import '../../widgets/scan_receipt_button.dart';
import '../../utils/category_styles.dart';
import '../../widgets/modern_bottom_toast.dart';
import '../../services/receipt_upload_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:camera/camera.dart';
import '../../theme/brand_theme.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final double? initialAmount;
  final String? initialVendor;
  final DateTime? initialDate;
  final String? initialCategory;
  final String? rawText;
  final String? capturedImagePath;
  final String? expenseIdToEdit;
  final bool showScanSuccessBanner;
  final bool needsReview;

  const AddExpenseScreen({
    super.key,
    this.initialAmount,
    this.initialVendor,
    this.initialDate,
    this.initialCategory,
    this.rawText,
    this.capturedImagePath,
    this.expenseIdToEdit,
    this.showScanSuccessBanner = false,
    this.needsReview = false,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _vendorController;
  String _selectedCategory = 'Food';
  DateTime _selectedDate = DateTime.now();
  bool _isAiCategory = false;
  bool _isSaving = false;
  
  File? _selectedReceiptImage;
  bool _isUploadingReceipt = false;
  String? _uploadedReceiptUrl;
  final ReceiptUploadService _receiptUploadService = ReceiptUploadService();

  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;
  bool _isCameraReady = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialAmount != null
          ? widget.initialAmount!.toStringAsFixed(2)
          : '',
    );
    _vendorController = TextEditingController(text: widget.initialVendor ?? '');

    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    } else {
      _selectedDate = DateTime.now();
    }

    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }

    if (widget.capturedImagePath != null) {
      _selectedReceiptImage = File(widget.capturedImagePath!);
    }

    _checkSmartVendor();

    if (widget.showScanSuccessBanner) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ModernBottomToast.show(
            context,
            message: 'Receipt scanned successfully',
            type: ModernToastType.success,
          );
        }
      });
    }

    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final firstCamera = cameras.first;
      _cameraController = CameraController(
        firstCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _initializeControllerFuture = _cameraController!.initialize();
      await _initializeControllerFuture;
      if (mounted) {
        setState(() {
          _isCameraReady = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _checkSmartVendor() async {
    if (widget.expenseIdToEdit != null) return;
    if (widget.initialVendor != null && widget.initialVendor!.isNotEmpty) {
      final vendorService = ref.read(vendorIntelligenceServiceProvider);
      final category = await vendorService.getCategoryForVendor(
        widget.initialVendor!,
      );
      if (category != null && mounted) {
        setState(() {
          _selectedCategory = category;
          _isAiCategory = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _vendorController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final theme = Theme.of(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showSnackBar(String message) {
    ModernBottomToast.show(
      context,
      message: message,
      type: ModernToastType.error,
    );
  }

  void _submitData() async {
    if (_isSaving) return;
    final enteredAmount = double.tryParse(_amountController.text);
    final enteredVendor = _vendorController.text.trim();

    if (enteredAmount == null || enteredAmount <= 0) {
      _showSnackBar("Please enter a valid amount");
      return;
    }

    if (enteredVendor.isEmpty) {
      _showSnackBar("Please enter a merchant name");
      return;
    }

    // Basic validation: vendor should contain at least one letter to avoid numeric-only values
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(enteredVendor);
    if (!hasLetter) {
      _showSnackBar("Please enter a valid merchant name (letters required)");
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      if (_selectedReceiptImage != null && _uploadedReceiptUrl == null) {
        setState(() => _isUploadingReceipt = true);
        final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';
        _uploadedReceiptUrl = await _receiptUploadService.uploadReceipt(userId, _selectedReceiptImage!, context);
        setState(() => _isUploadingReceipt = false);
      }

      final newExpense = ExpenseModel(
        amount: enteredAmount,
        vendor: enteredVendor,
        category: _selectedCategory,
        date: _selectedDate,
        needsReview: widget.needsReview,
        receiptImageUrl: _uploadedReceiptUrl,
      );

      final svc = ref.read(expenseServiceProvider);
      if (widget.expenseIdToEdit != null) {
        // Edit mode
        await svc.updateExpense(widget.expenseIdToEdit!, newExpense);
      } else {
        // Add mode
        await svc.addExpense(newExpense);
      }

      final vendorService = ref.read(vendorIntelligenceServiceProvider);
      await vendorService.saveVendorCategory(enteredVendor, _selectedCategory);

      // AI Logic: Check for OCR corrections (amount and/or vendor)
      if (widget.rawText != null) {
        final amountChanged =
            widget.initialAmount != null &&
            widget.initialAmount != enteredAmount;
        final vendorChanged =
            widget.initialVendor != null &&
            widget.initialVendor != enteredVendor;

        if (amountChanged || vendorChanged) {
          await vendorService.logOcrCorrection(
            rawText: widget.rawText!,
            systemSuggestedAmount: widget.initialAmount ?? enteredAmount,
            userCorrectedAmount: enteredAmount,
            systemSuggestedVendor: widget.initialVendor,
            userCorrectedVendor: enteredVendor,
          );
        }
      }

      if (mounted) {
        ModernBottomToast.show(
          context,
          message: 'Expense saved successfully',
          type: ModernToastType.success,
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.startsWith('Exception: Failed to save:')) {
          msg = msg.replaceFirst('Exception: ', '');
        } else {
          msg = 'Failed to save: $e';
        }
        ModernBottomToast.show(
          context,
          message: msg,
          type: ModernToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF3F7F8);
    final sheetColor = isDark
          ? Theme.of(context).colorScheme.surfaceContainerHighest ?? const Color(0xFF1E293B)
          : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: textColor),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.of(context).pushReplacementNamed('/');
            }
          },
        ),
        centerTitle: true,
        title: Text(
          widget.expenseIdToEdit != null ? "Edit Expense" : "Add Expense",
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _amountController.clear();
                _vendorController.clear();
                _selectedDate = DateTime.now();
                _selectedCategory = 'Food';
                _selectedReceiptImage = null;
                _uploadedReceiptUrl = null;
              });
            },
            child: Text(
              "Reset",
              style: TextStyle(color: subTextColor, fontSize: 14),
            ),
          )
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  decoration: BoxDecoration(
                    color: sheetColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Text(
                              "TOTAL AMOUNT",
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 12,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  "RM ",
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IntrinsicWidth(
                                  child: TextField(
                                    controller: _amountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: "0.00",
                                      hintStyle: TextStyle(color: subTextColor.withOpacity(0.5)),
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildInputField(
                        label: "Merchant / Vendor",
                        icon: Icons.storefront_rounded,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        child: TextField(
                          controller: _vendorController,
                          style: TextStyle(color: textColor, fontSize: 16),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "e.g. Village Grocer",
                            hintStyle: TextStyle(color: subTextColor.withOpacity(0.5)),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildInputField(
                        label: "Transaction Date",
                        icon: Icons.calendar_today_rounded,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        child: InkWell(
                          onTap: () => _selectDate(context),
                          child: Row(
                            children: [
                              Text(
                                DateFormat('dd MMMM yyyy').format(_selectedDate),
                                style: TextStyle(color: textColor, fontSize: 16),
                              ),
                              const Spacer(),
                              Icon(Icons.chevron_right_rounded, color: subTextColor),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "CATEGORY",
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 12,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "View All",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildCategorySection(isDark, textColor, subTextColor),
                      const SizedBox(height: 24),
                      _buildReceiptAttachmentSection(subTextColor),
                      const SizedBox(height: 32),
                      _buildGradientSaveButton(),
                      SizedBox(height: MediaQuery.of(context).padding.bottom),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required IconData icon,
    required Widget child,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: subTextColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        ReusableInputContainer(
          child: Row(
            children: [
              Icon(icon, color: subTextColor, size: 20),
              const SizedBox(width: 12),
              Expanded(child: child),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection(bool isDark, Color textColor, Color subTextColor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: kCategories.map((key) {
          final style = getCategoryStyle(key);
          final isSelected = _selectedCategory == key;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = key;
                _isAiCategory = false;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? style.color.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? style.color : (isDark ? Colors.white10 : Colors.black12),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    style.icon,
                    color: isSelected ? style.color : subTextColor,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    key,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? textColor : subTextColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReceiptAttachmentSection(Color subTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Receipt Attachment",
              style: TextStyle(
                color: subTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!kIsWeb && _selectedReceiptImage == null)
              GestureDetector(
                onTap: () {
                  // Direct to scanner logic here
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "Scan AI",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ReusableInputContainer(
          child: _selectedReceiptImage != null
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _FullScreenImageViewer(
                                imagePath: _selectedReceiptImage!.path,
                              ),
                            ),
                          );
                        },
                        child: Image.file(
                          _selectedReceiptImage!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedReceiptImage = null;
                            _uploadedReceiptUrl = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                )
              : SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _initializeControllerFuture == null
                        ? const Center(child: CircularProgressIndicator())
                        : FutureBuilder<void>(
                            future: _initializeControllerFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.done) {
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CameraPreview(_cameraController!),
                                    Positioned(
                                      bottom: 16,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: GestureDetector(
                                          onTap: () async {
                                            try {
                                              final image = await _cameraController!.takePicture();
                                              setState(() {
                                                _selectedReceiptImage = File(image.path);
                                              });
                                            } catch (e) {
                                              debugPrint('Error taking picture: $e');
                                            }
                                          },
                                          child: Container(
                                            height: 50,
                                            width: 50,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 3),
                                              color: Colors.white.withOpacity(0.3),
                                            ),
                                            child: Center(
                                              child: Container(
                                                height: 40,
                                                width: 40,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                return const Center(child: CircularProgressIndicator());
                              }
                            },
                          ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildGradientSaveButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.5), // Neon indigo glow
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: const LinearGradient(
          colors: [Color(0xFF818CF8), Color(0xFF6366F1)], // Indigo gradients
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isSaving ? null : _submitData,
          child: Center(
            child: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Save Expense",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen image viewer with pinch-to-zoom
// ─────────────────────────────────────────────────────────────────────────────
class _FullScreenImageViewer extends StatelessWidget {
  final String imagePath;
  const _FullScreenImageViewer({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Receipt',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Hero(tag: 'receipt_image', child: Image.file(File(imagePath))),
        ),
      ),
    );
  }
}

class ReusableInputContainer extends StatelessWidget {
  final Widget child;
  const ReusableInputContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: child,
    );
  }
}

