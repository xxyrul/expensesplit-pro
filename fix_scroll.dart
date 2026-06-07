import 'dart:io';

void replaceInFile(String filepath, List<List<String>> replacements) {
  final file = File(filepath);
  if (!file.existsSync()) {
    print('File not found: $filepath');
    return;
  }
  
  String content = file.readAsStringSync().replaceAll('\r\n', '\n');
  for (var i = 0; i < replacements.length; i++) {
    var pair = replacements[i];
    var oldText = pair[0].replaceAll('\r\n', '\n');
    var newText = pair[1].replaceAll('\r\n', '\n');
    if (content.contains(oldText)) {
      content = content.replaceAll(oldText, newText);
      print('Replaced chunk $i in $filepath');
    } else {
      print('Warning: Could not find target chunk $i in $filepath');
    }
  }
  file.writeAsStringSync(content);
}

void main() {
  final baseDir = 'admin_web/lib/screens';

  // 1. audit_log_screen.dart
  replaceInFile('$baseDir/audit_log_screen.dart', [
    [
      '''  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedActionFilter = 'All';

  // ── Filter logic''',
      '''  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedActionFilter = 'All';
  final ScrollController _vController = ScrollController();
  final ScrollController _hController = ScrollController();

  @override
  void dispose() {
    _vController.dispose();
    _hController.dispose();
    super.dispose();
  }

  // ── Filter logic'''
    ]
  ]);

  // 2. ocr_review_queue.dart
  replaceInFile('$baseDir/ocr_review_queue.dart', [
    [
      '''  Map<String, Map<String, String>> _userCache = {};

  @override
  void initState() {''',
      '''  Map<String, Map<String, String>> _userCache = {};
  final ScrollController _vController = ScrollController();
  final ScrollController _hController = ScrollController();

  @override
  void dispose() {
    _vController.dispose();
    _hController.dispose();
    super.dispose();
  }

  @override
  void initState() {'''
    ],
    [
      '''                                          : SingleChildScrollView(
                                              scrollDirection: Axis.vertical,
                                              child: SingleChildScrollView(
                                                scrollDirection: Axis.horizontal,
                                                child: ConstrainedBox(
                                                  constraints: BoxConstraints(minWidth: tableMinWidth),
                                                  child: DataTable(''',
      '''                                          : Scrollbar(
                                              controller: _vController,
                                              thumbVisibility: true,
                                              child: SingleChildScrollView(
                                                controller: _vController,
                                                scrollDirection: Axis.vertical,
                                                child: Scrollbar(
                                                  controller: _hController,
                                                  thumbVisibility: true,
                                                  notificationPredicate: (notif) => notif.depth == 1,
                                                  child: SingleChildScrollView(
                                                    controller: _hController,
                                                    scrollDirection: Axis.horizontal,
                                                    child: ConstrainedBox(
                                                      constraints: BoxConstraints(minWidth: tableMinWidth),
                                                      child: DataTable('''
    ],
    [
      '''                                                      );
                                                    }).toList(),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                    ),
                              ],''',
      '''                                                      );
                                                    }).toList(),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ),
                              ],'''
    ]
  ]);

  // 3. user_management.dart
  replaceInFile('$baseDir/user_management.dart', [
    [
      '''  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> _isMaskingActive() async {''',
      '''  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _vController = ScrollController();
  final ScrollController _hController = ScrollController();

  @override
  void dispose() {
    _vController.dispose();
    _hController.dispose();
    super.dispose();
  }

  Future<bool> _isMaskingActive() async {'''
    ],
    [
      '''                                            return Scrollbar(
                                              child: SingleChildScrollView(
                                                scrollDirection: Axis.horizontal,
                                                child: SizedBox(
                                                  width: tableWidth,
                                                  child: SingleChildScrollView(
                                                    scrollDirection: Axis.vertical,
                                                    child: DataTable(''',
      '''                                            return Scrollbar(
                                              controller: _vController,
                                              thumbVisibility: true,
                                              child: SingleChildScrollView(
                                                controller: _vController,
                                                scrollDirection: Axis.vertical,
                                                child: Scrollbar(
                                                  controller: _hController,
                                                  thumbVisibility: true,
                                                  notificationPredicate: (notif) => notif.depth == 1,
                                                  child: SingleChildScrollView(
                                                    controller: _hController,
                                                    scrollDirection: Axis.horizontal,
                                                    child: SizedBox(
                                                      width: tableWidth,
                                                      child: DataTable('''
    ],
    [
      '''                                                        });
                                                      }).toList(),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },''',
      '''                                                        });
                                                      }).toList(),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                      },'''
    ]
  ]);

  // 4. vendor_intelligence_hub.dart
  replaceInFile('$baseDir/vendor_intelligence_hub.dart', [
    [
      '''  String _ocrSearch = '';
  String _dictSearch = '';

  DateTime? _parseLogDate(Map<String, dynamic> data) {''',
      '''  String _ocrSearch = '';
  String _dictSearch = '';
  final ScrollController _vController = ScrollController();
  final ScrollController _hController = ScrollController();
  final ScrollController _dialogVController = ScrollController();
  final ScrollController _dialogHController = ScrollController();

  @override
  void dispose() {
    _vController.dispose();
    _hController.dispose();
    _dialogVController.dispose();
    _dialogHController.dispose();
    super.dispose();
  }

  DateTime? _parseLogDate(Map<String, dynamic> data) {'''
    ],
    [
      '''                return SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: 600),
                      child: DataTable(''',
      '''                return Scrollbar(
                  controller: _vController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _vController,
                    scrollDirection: Axis.vertical,
                    child: Scrollbar(
                      controller: _hController,
                      thumbVisibility: true,
                      notificationPredicate: (notif) => notif.depth == 1,
                      child: SingleChildScrollView(
                        controller: _hController,
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: 600),
                          child: DataTable('''
    ],
    [
      '''                                                      }).toList(),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },''',
      '''                                                      }).toList(),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },'''
    ],
    [
      '''                      return SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 700),
                            child: DataTable(''',
      '''                      return Scrollbar(
                        controller: _dialogVController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _dialogVController,
                          scrollDirection: Axis.vertical,
                          child: Scrollbar(
                            controller: _dialogHController,
                            thumbVisibility: true,
                            notificationPredicate: (notif) => notif.depth == 1,
                            child: SingleChildScrollView(
                              controller: _dialogHController,
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 700),
                                child: DataTable('''
    ],
    [
      '''                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        );
                      },''',
      '''                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },'''
    ]
  ]);

  // 5. expense_management.dart
  replaceInFile('$baseDir/expense_management.dart', [
    [
      '''                                            child: Scrollbar(
                                              controller: _horizontalScrollController,
                                              thumbVisibility: true,
                                              trackVisibility: true,
                                              child: SingleChildScrollView(''',
      '''                                            child: Scrollbar(
                                              controller: _horizontalScrollController,
                                              thumbVisibility: true,
                                              notificationPredicate: (notif) => notif.depth == 1,
                                              child: SingleChildScrollView('''
    ]
  ]);

  print("Replacements done.");
}
