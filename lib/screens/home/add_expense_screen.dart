import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/expense_model.dart';
import '../../services/expense_service.dart';
import '../../providers/expense_providers.dart';
import '../../services/vendor_intelligence_service.dart';
import '../../widgets/scan_receipt_button.dart';
import '../../utils/category_styles.dart';
import '../../widgets/modern_bottom_toast.dart';
import '../../services/receipt_upload_service.dart';
import '../../services/receipt_scanner_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/brand_theme.dart';
import 'camera_scanner_view.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final double? initialAmount;
  final String? initialVendor;
  final DateTime? initialDate;
  final String? initialCategory;
  final String? rawText;
  final String? capturedImagePath;
  final String? expenseIdToEdit;
  final String? initialReceiptUrl;
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
    this.initialReceiptUrl,
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
  String? _lastScannedRawText;
  final ReceiptUploadService _receiptUploadService = ReceiptUploadService();
  Timer? _debounceTimer;

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

    if (widget.initialReceiptUrl != null) {
      _uploadedReceiptUrl = widget.initialReceiptUrl;
    }

    if (widget.capturedImagePath != null) {
      _selectedReceiptImage = File(widget.capturedImagePath!);
      if (!widget.showScanSuccessBanner && widget.initialAmount == null && widget.initialVendor == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _processSelectedImage(widget.capturedImagePath!);
          }
        });
      }
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

    _retrieveLostData();
    _vendorController.addListener(_onVendorChanged);
  }

  void _onVendorChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      final text = _vendorController.text;
      if (text.isNotEmpty && mounted) {
        final category = await ref.read(vendorIntelligenceServiceProvider).getCategoryForVendor(text);
        if (category != null && mounted && _selectedCategory != category) {
          setState(() {
            _selectedCategory = category;
            _isAiCategory = true;
          });
        }
      }
    });
  }

  Future<void> _retrieveLostData() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final picker = ImagePicker();
        final response = await picker.retrieveLostData();
        if (response.isEmpty) {
          return;
        }
        if (response.file != null && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _processSelectedImage(response.file!.path);
          });
        } else if (response.exception != null && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ModernBottomToast.show(
                context,
                message: 'Error retrieving image: ${response.exception}',
                type: ModernToastType.error,
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error in retrieveLostData: $e");
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
    _debounceTimer?.cancel();
    _vendorController.removeListener(_onVendorChanged);
    _amountController.dispose();
    _vendorController.dispose();
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
      if (enteredAmount != null && _lastScannedRawText != null) {
        try {
          await ref.read(receiptScannerProvider).learnTotalKeyword(_lastScannedRawText!, enteredAmount);
        } catch (e) {
          debugPrint('Error learning keyword: $e');
        }
      }

      if (_selectedReceiptImage != null && _uploadedReceiptUrl == null) {
        setState(() => _isUploadingReceipt = true);
        final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';
        _uploadedReceiptUrl = await _receiptUploadService.uploadReceipt(userId, _selectedReceiptImage!, context);
        if (!mounted) return;
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
      vendorService.saveVendorCategory(enteredVendor, _selectedCategory);

      // AI Logic: Check for OCR corrections (amount and/or vendor)
      if (widget.rawText != null) {
        final amountChanged =
            widget.initialAmount != null &&
            widget.initialAmount != enteredAmount;
        final vendorChanged =
            widget.initialVendor != null &&
            widget.initialVendor != enteredVendor;

        if (amountChanged || vendorChanged) {
          vendorService.logOcrCorrection(
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
      floatingActionButton: FloatingActionButton(
        onPressed: _isSaving ? null : _submitData,
        backgroundColor: Theme.of(context).colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
        child: _isSaving 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : const Icon(Icons.check_rounded, color: Colors.white, size: 28),
      ),
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
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.05),
          child: Container(
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // --- RECEIPT ATTACHMENT / CAMERA (Top) ---
                _buildReceiptAttachmentSection(subTextColor),
                const SizedBox(height: 32),
                
                // --- TOTAL AMOUNT ---
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
                const SizedBox(height: 32),
                
                // --- FORM FIELDS (Merchant & Date) ---
                _buildInputField(
                  label: "Merchant / Vendor",
                  icon: Icons.storefront_rounded,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  child: TextField(
                    controller: _vendorController,
                    style: TextStyle(color: textColor, fontSize: 16),
                    decoration: InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      hintText: "e.g. Village Grocer",
                      hintStyle: TextStyle(color: subTextColor.withOpacity(0.5)),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
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
                      const SizedBox(height: 32),
                      
                      // --- CATEGORY GRID ---
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
                      _buildCategoryGrid(isDark, textColor, subTextColor),
                      
                      const SizedBox(height: 80),
                      SizedBox(height: MediaQuery.of(context).padding.bottom),
                    ],
                  ),
                ),
              ),
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
        FormFieldWrapper(
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

  Widget _buildCategoryGrid(bool isDark, Color textColor, Color subTextColor) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 20,
      crossAxisSpacing: 8,
      childAspectRatio: 0.7, // Fixes the "Bottom Overflowed" error
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primary : (isDark ? const Color(0xFF1E293B) : Colors.white),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Theme.of(context).colorScheme.primary : (isDark ? Colors.white10 : Colors.black12),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ] : [],
                ),
                child: Center(
                  child: Icon(
                    style.icon,
                    color: isSelected ? Colors.white : subTextColor,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  key,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Theme.of(context).colorScheme.primary : subTextColor,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Add Receipt",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded),
                  title: const Text("Take a Picture"),
                  onTap: () async {
                    Navigator.pop(context);
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 85,
                      maxWidth: 1920,
                      maxHeight: 1920,
                    );
                    if (pickedFile != null) {
                      _processSelectedImage(pickedFile.path);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: const Text("Choose from Gallery"),
                  onTap: () async {
                    Navigator.pop(context);
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                      maxWidth: 1920,
                      maxHeight: 1920,
                    );
                    if (pickedFile != null) {
                      _processSelectedImage(pickedFile.path);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _processSelectedImage(String filePath) async {
    setState(() {
      _selectedReceiptImage = File(filePath);
    });

    // Show processing toast
    ModernBottomToast.show(
      context,
      message: 'Scanning receipt with AI...',
      type: ModernToastType.info,
    );

    final scanner = ref.read(receiptScannerProvider);
    final result = await scanner.processImageFile(filePath);

    if (result != null && mounted) {
      setState(() {
        if (result['rawText'] != null) {
          _lastScannedRawText = result['rawText'].toString();
        }
        if (result['amount'] != null) {
          _amountController.text = result['amount'].toString();
        }
        if (result['vendor'] != null) {
          final scannedVendor = result['vendor'].toString();
          _vendorController.text = scannedVendor;
          
          if (scannedVendor.isNotEmpty) {
            ref.read(vendorIntelligenceServiceProvider)
               .getCategoryForVendor(scannedVendor)
               .then((smartCategory) {
                 if (smartCategory != null && mounted) {
                   setState(() {
                     _selectedCategory = smartCategory;
                     _isAiCategory = true;
                   });
                 }
            });
          }
        }
        if (result['category'] != null && kCategories.contains(result['category']) && !_isAiCategory) {
          _selectedCategory = result['category'];
          _isAiCategory = true;
        }
        if (result['date'] != null) {
          _selectedDate = result['date'];
        }
      });
      ModernBottomToast.show(
        context,
        message: 'Receipt parsed successfully',
        type: ModernToastType.success,
      );
    } else if (mounted) {
      ModernBottomToast.show(
        context,
        message: 'Could not read receipt details',
        type: ModernToastType.error,
      );
    }
  }

  Widget _buildReceiptAttachmentSection(Color subTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: () {
              if (_selectedReceiptImage != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _FullScreenImageViewer(imagePath: _selectedReceiptImage!.path),
                  ),
                );
              } else if (_uploadedReceiptUrl != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _FullScreenImageViewer(networkUrl: _uploadedReceiptUrl),
                  ),
                );
              } else {
                _showImagePickerModal();
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A2C) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: (_selectedReceiptImage != null || _uploadedReceiptUrl != null)
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_selectedReceiptImage != null)
                                Image.file(
                                  _selectedReceiptImage!,
                                  fit: BoxFit.cover,
                                )
                              else if (_uploadedReceiptUrl != null)
                                CachedNetworkImage(
                                  imageUrl: _uploadedReceiptUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Center(child: Icon(Icons.broken_image, size: 40)),
                                ),
                              Container(
                                color: Colors.black.withOpacity(0.2),
                                child: const Center(
                                  child: Icon(Icons.visibility, color: Colors.white, size: 32),
                                ),
                              )
                            ],
                          )
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_a_photo_rounded, size: 40, color: subTextColor.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                Text(
                                  "Attach Receipt",
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                if (_selectedReceiptImage != null || _uploadedReceiptUrl != null)
                  Positioned(
                    top: -10,
                    right: -10,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedReceiptImage = null;
                          _uploadedReceiptUrl = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_selectedReceiptImage != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              "Tap to preview receipt",
              style: TextStyle(
                color: subTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen image viewer with pinch-to-zoom
// ─────────────────────────────────────────────────────────────────────────────
class _FullScreenImageViewer extends StatelessWidget {
  final String? imagePath;
  final String? networkUrl;

  const _FullScreenImageViewer({this.imagePath, this.networkUrl});

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
          child: imagePath != null
              ? Hero(tag: 'receipt_image', child: Image.file(File(imagePath!)))
              : CachedNetworkImage(
                  imageUrl: networkUrl!,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.broken_image, color: Colors.white, size: 50),
                ),
        ),
      ),
    );
  }
}

class FormFieldWrapper extends StatelessWidget {
  final Widget child;
  const FormFieldWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2C) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: child,
    );
  }
}

