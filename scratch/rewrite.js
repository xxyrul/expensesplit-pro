const fs = require('fs');

const filePath = 'C:\\\\Users\\\\arul\\\\OneDrive\\\\Desktop\\\\expensesplit_pro\\\\lib\\\\screens\\\\home\\\\add_expense_screen.dart';
let content = fs.readFileSync(filePath, 'utf-8');

const newBody = `body: CustomScrollView(
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // --- RECEIPT ATTACHMENT / CAMERA (Top) ---
                      _buildReceiptAttachmentSection(subTextColor),
                      const SizedBox(height: 24),
                      
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
                      
                      // --- GROUPED FIELDS (Merchant & Date) ---
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHigh ?? const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
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
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(height: 1, color: Colors.white10),
                            ),
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
                          ],
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
              ],
            ),
          ),
        ],
      ),`;

const categoryGrid = \`Widget _buildCategoryGrid(bool isDark, Color textColor, Color subTextColor) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 20,
      crossAxisSpacing: 8,
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
              Text(
                key,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Theme.of(context).colorScheme.primary : subTextColor,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }\`;

const receiptSection = \`Widget _buildReceiptAttachmentSection(Color subTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            if (_selectedReceiptImage != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _FullScreenImageViewer(imagePath: _selectedReceiptImage!.path),
                ),
              );
            }
          },
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 128,
                height: 176,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.black12,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ]
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: _selectedReceiptImage != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              _selectedReceiptImage!,
                              fit: BoxFit.cover,
                            ),
                            Container(
                              color: Colors.black.withOpacity(0.2),
                              child: const Center(
                                child: Icon(Icons.visibility, color: Colors.white, size: 32),
                              ),
                            )
                          ],
                        )
                      : (_initializeControllerFuture == null
                          ? const Center(child: CircularProgressIndicator())
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                CameraPreview(_cameraController!),
                                Positioned.fill(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
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
                                      child: Container(),
                                    )
                                  )
                                )
                              ],
                            )),
                ),
              ),
              if (_selectedReceiptImage != null)
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
        const SizedBox(height: 12),
        Text(
          _selectedReceiptImage != null ? "Tap to preview receipt" : "Tap camera to capture receipt",
          style: TextStyle(
            color: subTextColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }\`;

const bodyStart = content.indexOf('body: CustomScrollView(');
const bodyEnd = content.indexOf('Widget _buildInputField(');

let newContent = content.substring(0, bodyStart) + newBody + '\\n    );\\n  }\\n\\n  ' + content.substring(bodyEnd);

const catStart = newContent.indexOf('Widget _buildCategorySection');
const catEnd = newContent.indexOf('Widget _buildReceiptAttachmentSection');
newContent = newContent.substring(0, catStart) + categoryGrid + '\\n\\n  ' + newContent.substring(catEnd);

const recStart = newContent.indexOf('Widget _buildReceiptAttachmentSection');
const recEnd = newContent.indexOf('class _FullScreenImageViewer');

newContent = newContent.substring(0, recStart) + receiptSection + '\\n\\n} // End of class\\n\\n// ' + newContent.substring(recEnd);

fs.writeFileSync(filePath, newContent);
console.log("done");
