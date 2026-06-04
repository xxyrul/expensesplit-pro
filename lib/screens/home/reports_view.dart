import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/expense_service.dart';
import '../../providers/expense_providers.dart';
import '../../models/expense_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/brand_theme.dart';
import '../../utils/category_styles.dart';
import '../../services/export_service.dart';
import '../../providers/export_providers.dart';
import '../../widgets/insights_carousel.dart';
import '../../widgets/ai_advisor_card.dart';
import '../../widgets/modern_bottom_toast.dart';
import '../report_generator_screen.dart';

class ReportsView extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  const ReportsView({super.key, this.onBack});

  @override
  ConsumerState<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends ConsumerState<ReportsView> {
  late String _selectedMonth;
  late List<DateTime> _availableMonthsDates;
  String _selectedTab = 'Categories';
  final List<String> _tabs = ['Categories', 'Merchants'];
  bool _showDailyAverage = false;
  int _touchedCategoryIndex = -1;

  @override
  void initState() {
    super.initState();
    _availableMonthsDates = [];
    final now = DateTime.now();
    for (int i = 0; i < 6; i++) {
      _availableMonthsDates.add(DateTime(now.year, now.month - i, 1));
    }
    _availableMonthsDates = _availableMonthsDates.reversed.toList();
    _selectedMonth = DateFormat('MMMM yyyy').format(_availableMonthsDates.last);
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesStreamProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: expensesAsync.when(
        data: (expenses) {
          final filtered = _filterExpenses(expenses, _selectedMonth);

          return Column(
            children: [
              // ── Gradient header (NO SafeArea wrapper so it bleeds to top) ──
              Container(
                width: double.infinity,
                // Top padding absorbs the status-bar height dynamically
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 20,
                ),
                decoration: BoxDecoration(
                  gradient: context.brandHeaderGradient,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    _buildTopBar(context, filtered),
                    _buildMonthSelector(),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 120,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      _buildDonutChart(filtered),
                      const SizedBox(height: 20),
                      _buildTabBar(),
                      const SizedBox(height: 16),
                      // ── Tab content ──
                      _buildTabContent(filtered),
                      const SizedBox(height: 30),
                      InsightsCarousel(
                        expenses: filtered,
                        onTopExpenseTapped: (expense) {
                          _showExpenseDetailsSheet(context, expense);
                        },
                        onFrequentVendorTapped: (vendor) {
                          _showTransactionsSheet(
                            context,
                            'Vendor',
                            vendor,
                            filtered,
                          );
                        },
                        onTopCategoryTapped: (category) {
                          _showTransactionsSheet(
                            context,
                            'Category',
                            category,
                            filtered,
                          );
                        },
                      ),
                      const SizedBox(height: 15),
                      AiAdvisorCard(
                        totalSpent: filtered.fold(0.0, (s, e) => s + e.amount),
                        dateStr: DateFormat('yyyy-MM-dd').format(DateFormat('MMMM yyyy').parse(_selectedMonth)),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  // ────────────────────────── helpers ──────────────────────────

  List<ExpenseModel> _filterExpenses(List<ExpenseModel> all, String monthStr) {
    return all
        .where((e) => DateFormat('MMMM yyyy').format(e.date) == monthStr)
        .toList();
  }

  Widget _buildTopBar(BuildContext context, List<ExpenseModel> filtered) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 48,
            child: Align(
              alignment: Alignment.centerLeft,
              child: widget.onBack != null
                  ? Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        onPressed: widget.onBack,
                      ),
                    )
                  : const SizedBox(),
            ),
          ),
          const Expanded(
            child: Text(
              'Reports & Insights',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ReportGeneratorScreen()),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Month selector ──
  Widget _buildMonthSelector() {
    final now = DateTime.now();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: _availableMonthsDates.map((date) {
          final fullLabel = DateFormat('MMMM yyyy').format(date);
          final isSelected = _selectedMonth == fullLabel;

          String label = DateFormat('MMM').format(date).toUpperCase();
          if (date.year != now.year)
            label = '$label${DateFormat('yy').format(date)}';

          return GestureDetector(
            onTap: () => setState(() => _selectedMonth = fullLabel),
            child: Container(
              margin: const EdgeInsets.only(right: 24),
              child: Column(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 3,
                    width: 28,
                    color: isSelected ? Colors.white : Colors.transparent,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Donut chart ──
  Widget _buildDonutChart(List<ExpenseModel> expenses) {
    final Map<String, double> catTotals = {};
    double total = 0;
    for (final e in expenses) {
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
      total += e.amount;
    }

    final entries = catTotals.entries.toList();

    List<PieChartSectionData> sections;
    if (total == 0) {
      sections = [
        PieChartSectionData(
          color: Colors.grey.withOpacity(0.2),
          value: 1,
          title: '',
          radius: 30,
        ),
      ];
    } else {
      sections = entries.asMap().entries.map((entry) {
        final i = entry.key;
        final key = entry.value.key;
        final value = entry.value.value;
        final style = getCategoryStyle(key);
        final isTouched = i == _touchedCategoryIndex;
        final radius = isTouched ? 38.0 : 30.0;
        return PieChartSectionData(
          color: style.color,
          value: value,
          title: '',
          radius: radius,
        );
      }).toList();
    }

    final selDate = DateFormat('MMMM yyyy').parse(_selectedMonth);
    final now = DateTime.now();
    int daysToDivide = 1;
    if (selDate.year == now.year && selDate.month == now.month) {
      daysToDivide = now.day;
    } else {
      daysToDivide = DateTime(selDate.year, selDate.month + 1, 0).day;
    }
    final dailyAvg = total / daysToDivide;

    final displayLabel = _showDailyAverage ? 'Daily Average' : 'Spent So Far';
    final displayValue = _showDailyAverage ? dailyAvg : total;

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 220,
          width: 220,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  if (event is! FlTapUpEvent) return;

                  setState(() {
                    if (pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      _touchedCategoryIndex = -1;
                      return;
                    }
                    int tappedIndex =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                    if (_touchedCategoryIndex == tappedIndex) {
                      _touchedCategoryIndex =
                          -1; // Toggle off if tapping the same slice
                    } else {
                      _touchedCategoryIndex = tappedIndex; // Toggle on
                    }
                  });
                },
              ),
              sectionsSpace: 0,
              centerSpaceRadius: 85,
              startDegreeOffset: -90,
              sections: sections,
            ),
          ),
        ),
        if (_touchedCategoryIndex != -1 &&
            _touchedCategoryIndex < entries.length)
          Builder(
            builder: (context) {
              final key = entries[_touchedCategoryIndex].key;
              final amount = entries[_touchedCategoryIndex].value;
              final pct = (amount / total * 100).toStringAsFixed(1);
              final style = getCategoryStyle(key);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(style.icon, color: style.color, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    '$pct%',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    key,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          )
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  if (_showDailyAverage)
                    setState(() => _showDailyAverage = false);
                },
                child: Icon(
                  Icons.keyboard_arrow_up,
                  color: _showDailyAverage
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.withOpacity(0.4),
                  size: 24,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayLabel,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.info_outline,
                    color: const Color(0xFF475569).withOpacity(0.7),
                    size: 13,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'RM ${displayValue.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () {
                  if (!_showDailyAverage)
                    setState(() => _showDailyAverage = true);
                },
                child: Icon(
                  Icons.keyboard_arrow_down,
                  color: !_showDailyAverage
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.withOpacity(0.4),
                  size: 24,
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ── Tab bar (Categories / Merchants) ──
  Widget _buildTabBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: _tabs.map((tab) {
          final isSelected = _selectedTab == tab;
          return GestureDetector(
            onTap: () => setState(() => _selectedTab = tab),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? null
                    : Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1.5),
              ),
              child: Text(
                tab,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Tab content dispatcher ──
  Widget _buildTabContent(List<ExpenseModel> expenses) {
    switch (_selectedTab) {
      case 'Categories':
        return _buildCategoriesTab(expenses);
      case 'Merchants':
        return _buildMerchantsTab(expenses);
      default:
        return const Center(child: Text('Coming soon'));
    }
  }

  // ── Categories tab ──
  Widget _buildCategoriesTab(List<ExpenseModel> expenses) {
    final Map<String, double> totals = {};
    double grand = 0;
    for (final e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
      grand += e.amount;
    }

    if (grand == 0) {
      return const Center(
        child: Text(
          'No spending this month.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final sorted = totals.keys.toList()
      ..sort((a, b) => totals[b]!.compareTo(totals[a]!));

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, i) {
        final key = sorted[i];
        final amount = totals[key]!;
        final pct = amount / grand;
        final style = getCategoryStyle(key);

        return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [style.color, style.color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(style.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        key,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'RM ${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(style.color),
                      minHeight: 7,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Merchants tab ──
  Widget _buildMerchantsTab(List<ExpenseModel> expenses) {
    final Map<String, double> totals = {};
    for (final e in expenses) {
      totals[e.vendor] = (totals[e.vendor] ?? 0) + e.amount;
    }

    if (totals.isEmpty) {
      return const Center(
        child: Text(
          'No spending this month.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final sorted = totals.keys.toList()
      ..sort((a, b) => totals[b]!.compareTo(totals[a]!));

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final merchant = sorted[i];
        final initials = merchant.isNotEmpty ? merchant[0].toUpperCase() : '?';

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          title: Text(
            merchant,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          trailing: Text(
            '-RM ${totals[merchant]!.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Color(0xFFf43f5e),
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  void _showExpenseDetailsSheet(BuildContext context, ExpenseModel expense) {
    final style = getCategoryStyle(expense.category);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: style.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(style.icon, size: 40, color: style.color),
              ),
              const SizedBox(height: 16),
              const Text(
                'Top Expense Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildDetailRow(
                'Amount',
                'RM ${expense.amount.toStringAsFixed(2)}',
                isAmount: true,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Vendor',
                expense.vendor.isEmpty ? 'Unknown' : expense.vendor,
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Category', expense.category),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Date',
                DateFormat('dd MMM yyyy').format(expense.date),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAmount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 15)),
        Text(
          value,
          style: TextStyle(
            fontWeight: isAmount ? FontWeight.w800 : FontWeight.w600,
            fontSize: isAmount ? 18 : 15,
            color: isAmount ? const Color(0xFFf43f5e) : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  void _showTransactionsSheet(
    BuildContext context,
    String filterType,
    String filterValue,
    List<ExpenseModel> allExpenses,
  ) {
    final filteredList = allExpenses.where((e) {
      if (filterType == 'Vendor') return e.vendor == filterValue;
      return e.category == filterValue;
    }).toList();

    // sort by date descending
    filteredList.sort((a, b) => b.date.compareTo(a.date));

    final total = filteredList.fold(0.0, (sum, e) => sum + e.amount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  filterValue,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total Spent: RM ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFFf43f5e),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    itemCount: filteredList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final exp = filteredList[index];
                      final style = getCategoryStyle(exp.category);
                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: style.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              style.icon,
                              color: style.color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  filterType == 'Vendor'
                                      ? exp.category
                                      : (exp.vendor.isEmpty
                                            ? 'Unknown'
                                            : exp.vendor),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('dd MMM yyyy').format(exp.date),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '-RM ${exp.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
