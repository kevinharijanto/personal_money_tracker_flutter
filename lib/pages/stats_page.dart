import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../state/transactions_state.dart';
import '../utils/money_formatter.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  static const List<String> _modeKeys = ['daily', 'monthly', 'yearly'];
  int _modeIndex = 0;
  DateTime _selectedDate = DateTime.now();
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String _selectedType = 'EXPENSE';
  final List<Color> _chartPalette = [
    const Color(0xffF66D6D),
    const Color(0xffF9A84D),
    const Color(0xffFFD166),
    const Color(0xff4ECDC4),
    const Color(0xff6C5CE7),
    const Color(0xff00B894),
    const Color(0xff0984E3),
    const Color(0xffE84393),
    const Color(0xff2D3436),
  ];

  @override
  void initState() {
    super.initState();
    _applyDateRangeFromSelected();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransactions();
    });
  }

  void _applyDateRangeFromSelected() {
    if (_modeIndex == 0) {
      _dateFrom = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      _dateTo = _dateFrom!.add(const Duration(days: 1));
    } else if (_modeIndex == 1) {
      _dateFrom = DateTime(_selectedDate.year, _selectedDate.month, 1);
      _dateTo = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
    } else {
      _dateFrom = DateTime(_selectedDate.year, 1, 1);
      _dateTo = DateTime(_selectedDate.year + 1, 1, 1);
    }
  }

  Future<void> _loadTransactions({bool force = false}) async {
    final state = context.read<TransactionsState>();
    await state.loadForAccountWithDateRange(
      accountId: '',
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      force: force,
    );
  }

  void _showComingSoon(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _refresh() async {
    await _loadTransactions(force: true);
  }

  void _switchMode(int index) {
    if (_modeIndex == index) return;
    setState(() {
      _modeIndex = index;
      _applyDateRangeFromSelected();
    });
    _loadTransactions(force: true);
  }

  void _navigateDateRange(bool forward) {
    setState(() {
      if (_modeIndex == 0) {
        _selectedDate = _selectedDate.add(Duration(days: forward ? 1 : -1));
      } else if (_modeIndex == 1) {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + (forward ? 1 : -1), _selectedDate.day);
      } else {
        _selectedDate = DateTime(_selectedDate.year + (forward ? 1 : -1), _selectedDate.month, _selectedDate.day);
      }
      _applyDateRangeFromSelected();
    });
    _loadTransactions(force: true);
  }

  Future<void> _openDatePicker() async {
    DateTime? picked;
    if (_modeIndex == 0) {
      picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
    } else if (_modeIndex == 1) {
      picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        helpText: 'Pick a day within the month',
      );
      if (picked != null) {
        picked = DateTime(picked.year, picked.month, 1);
      }
    } else {
      picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        helpText: 'Pick a day within the year',
      );
      if (picked != null) {
        picked = DateTime(picked.year, 1, 1);
      }
    }

    if (picked != null) {
      setState(() {
        _selectedDate = picked!;
        _applyDateRangeFromSelected();
      });
      _loadTransactions(force: true);
    }
  }

  String _formatDateRange() {
    if (_dateFrom == null || _dateTo == null) return '';
    if (_modeIndex == 0) {
      return DateFormat('d MMM yyyy').format(_dateFrom!);
    } else if (_modeIndex == 1) {
      return DateFormat('MMM yyyy').format(_dateFrom!);
    } else {
      return DateFormat('yyyy').format(_dateFrom!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: Consumer<TransactionsState>(
                  builder: (context, transactionsState, child) {
                    if (transactionsState.isLoading && !transactionsState.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (transactionsState.error != null && !transactionsState.hasData) {
                      return Center(
                        child: Text('Error: ${transactionsState.error}'),
                      );
                    }

                    final txs = transactionsState.transactions;
                    if (txs.isEmpty) {
                      return ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          _buildModeSelector(),
                          const SizedBox(height: 12),
                          _buildDateSelector(),
                          const SizedBox(height: 24),
                          Center(
                            child: Text(
                              'No transactions for this period.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      );
                    }

                    final income = _sumByType(txs, 'INCOME');
                    final expense = _sumByType(txs, 'EXPENSE');
                    final sections = _aggregateByCategory(txs.where((t) => t.type == _selectedType).toList());

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildModeSelector(),
                        const SizedBox(height: 12),
                        _buildDateSelector(),
                        const SizedBox(height: 16),
                        _buildSummaryRow(income, expense),
                        const SizedBox(height: 16),
                        _buildTypeSwitcher(),
                        const SizedBox(height: 16),
                        _buildPieChart(sections),
                        const SizedBox(height: 16),
                        ..._buildCategoryList(sections),
                        const SizedBox(height: 32),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
              Column(
                children: [
                  Text(
                    'Stats',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Income & Expense overview',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(width: 48), // balance leading button width
            ],
          ),
          const SizedBox(height: 8),
          _buildModeSelector(),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    final theme = Theme.of(context);
    final highlight = Colors.redAccent;
    final idle = theme.textTheme.bodySmall?.color?.withOpacity(0.6) ?? Colors.grey;

    return Row(
      children: List.generate(_modeKeys.length, (index) {
        final isActive = _modeIndex == index;
        final label = _modeKeys[index][0].toUpperCase() + _modeKeys[index].substring(1);
        return Expanded(
          child: GestureDetector(
            onTap: () => _switchMode(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? highlight.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? highlight : idle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDateSelector() {
    return Row(
      children: [
        IconButton(
          onPressed: () => _navigateDateRange(false),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: GestureDetector(
            onTap: _openDatePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              ),
              child: Text(
                _formatDateRange(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () => _navigateDateRange(true),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(double income, double expense) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Income', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
              const SizedBox(height: 4),
              Text(MoneyFormatter.formatIDR(income), style: theme.textTheme.titleMedium?.copyWith(color: Colors.blueAccent, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Expenses', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
              const SizedBox(height: 4),
              Text(MoneyFormatter.formatIDR(expense), style: theme.textTheme.titleMedium?.copyWith(color: Colors.redAccent, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSwitcher() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedType = 'INCOME'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _selectedType == 'INCOME' ? theme.colorScheme.surface : Colors.transparent,
                ),
                child: Text(
                  'Income',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _selectedType == 'INCOME' ? theme.colorScheme.primary : theme.textTheme.bodySmall?.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedType = 'EXPENSE'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _selectedType == 'EXPENSE' ? theme.colorScheme.surface : Colors.transparent,
                ),
                child: Text(
                  'Expenses',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _selectedType == 'EXPENSE' ? Colors.redAccent : theme.textTheme.bodySmall?.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(List<_CategoryShare> shares) {
    final total = shares.fold<double>(0, (sum, e) => sum + e.amount);
    if (total == 0) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: Text(
          'No data for ${_selectedType.toLowerCase()}s',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AspectRatio(
        aspectRatio: 1.2,
        child: PieChart(
          PieChartData(
            centerSpaceRadius: 40,
            sectionsSpace: 2,
            sections: List.generate(shares.length, (index) {
              final share = shares[index];
              final percent = share.amount / total * 100;
              return PieChartSectionData(
                color: _chartPalette[index % _chartPalette.length],
                value: share.amount,
                title: '${percent.toStringAsFixed(0)}%',
                radius: 110,
                titleStyle:
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              );
            }),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCategoryList(List<_CategoryShare> shares) {
    if (shares.isEmpty) {
      return [
        Center(
          child: Text(
            'No category data.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ];
    }

    final total = shares.fold<double>(0, (sum, e) => sum + e.amount);
    return List.generate(shares.length, (index) {
      final share = shares[index];
      final percent = total == 0 ? 0 : (share.amount / total * 100);
      final color = _chartPalette[index % _chartPalette.length];

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '${percent.toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    share.category,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    MoneyFormatter.formatIDR(share.amount),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  double _sumByType(List<TransactionModel> txs, String type) {
    double total = 0;
    for (final tx in txs) {
      if (tx.type == type) {
        total += tx.amount.abs();
      }
    }
    return total;
  }

  List<_CategoryShare> _aggregateByCategory(List<TransactionModel> txs) {
    if (txs.isEmpty) return [];
    final Map<String, double> bucket = {};
    for (final tx in txs) {
      final key = tx.categoryName.isNotEmpty ? tx.categoryName : 'Uncategorized';
      bucket[key] = (bucket[key] ?? 0) + tx.amount.abs();
    }
    final shares = bucket.entries
        .map((e) => _CategoryShare(category: e.key, amount: e.value))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return shares;
  }
}

class _CategoryShare {
  final String category;
  final double amount;

  _CategoryShare({required this.category, required this.amount});
}
