import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../pages/transaction_detail_page.dart';
import '../utils/money_formatter.dart';
import '../state/accounts_state.dart';
import '../state/transactions_state.dart';
import '../widgets/app_loading.dart';
import '../widgets/app_error.dart';

class AccountTransactionsPage extends StatefulWidget {
  final String accountId;
  final String accountName;
  final String currency;
  final double currentBalance;
  final bool showAppBar;

  const AccountTransactionsPage({
    super.key,
    required this.accountId,
    required this.accountName,
    required this.currency,
    required this.currentBalance,
    this.showAppBar = true,
  });

  @override
  State<AccountTransactionsPage> createState() =>
      _AccountTransactionsPageState();
}

class _AccountTransactionsPageState extends State<AccountTransactionsPage> {
  bool _hasChanged = false;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  static const List<String> _modeKeys = ['daily', 'monthly', 'yearly'];
  String _viewMode = _modeKeys[0]; // controls filtering
  int _modeIndex = 0;

  static const Map<String, String> _tabLabels = {
    'daily': 'Daily',
    'monthly': 'Monthly',
    'yearly': 'Yearly',
  };

  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    // Initialize with current day for daily view
    _selectedDate = DateTime.now().toLocal();
    _applyDateRangeFromSelected();
    
    // Use addPostFrameCallback to ensure state changes happen after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndFetchTransactions();
    });
  }

  void _initializeAndFetchTransactions() {
    // Load transactions using TransactionsState
    final transactionsState = context.read<TransactionsState>();
    transactionsState.loadForAccountWithDateRange(
      accountId: widget.accountId,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      force: false, // Don't force when initializing
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _refresh() async {
    final transactionsState = context.read<TransactionsState>();
    await transactionsState.refreshForAccountWithDateRange(
      accountId: widget.accountId,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
  }

  void _handleTabTap(String tabId) {
    if (_viewMode == tabId) return;
    _switchViewMode(tabId);
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

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 200) return;
    if (velocity < 0) {
      _moveToAdjacentMode(forward: true);
    } else {
      _moveToAdjacentMode(forward: false);
    }
  }

  void _moveToAdjacentMode({required bool forward}) {
    if (forward && _modeIndex < _modeKeys.length - 1) {
      _switchViewMode(_modeKeys[_modeIndex + 1]);
    } else if (!forward && _modeIndex > 0) {
      _switchViewMode(_modeKeys[_modeIndex - 1]);
    }
  }

  void _applyDateRangeFromSelected({DateTime? newSelected}) {
    final target = newSelected ?? _selectedDate;
    _selectedDate = target;
    if (_viewMode == 'daily') {
      _dateFrom = DateTime(target.year, target.month, target.day);
      _dateTo = _dateFrom!.add(const Duration(days: 1));
    } else if (_viewMode == 'monthly') {
      _dateFrom = DateTime(target.year, target.month, 1);
      _dateTo = DateTime(target.year, target.month + 1, 0);
    } else {
      _dateFrom = DateTime(target.year, 1, 1);
      _dateTo = DateTime(target.year + 1, 1, 0);
    }
  }

  DateTime _clampDate(int year, int month, int day) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final safeDay = day.clamp(1, lastDayOfMonth);
    return DateTime(year, month, safeDay);
  }

  Future<void> _navigateDateRange({bool forward = true}) async {
    if (_dateFrom == null || _dateTo == null) return;
    
    DateTime newSelected;
    if (_viewMode == 'daily') {
      final delta = forward ? 1 : -1;
      newSelected = _selectedDate.add(Duration(days: delta));
    } else if (_viewMode == 'monthly') {
      final offset = forward ? 1 : -1;
      final intermediate =
          DateTime(_selectedDate.year, _selectedDate.month + offset, 1);
      newSelected = _clampDate(
        intermediate.year,
        intermediate.month,
        _selectedDate.day,
      );
    } else {
      final newYear = _selectedDate.year + (forward ? 1 : -1);
      newSelected = _clampDate(newYear, _selectedDate.month, _selectedDate.day);
    }

    setState(() {
      _applyDateRangeFromSelected(newSelected: newSelected);
    });
    
    // Use addPostFrameCallback to ensure state changes happen after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final transactionsState = context.read<TransactionsState>();
      transactionsState.refreshForAccountWithDateRange(
        accountId: widget.accountId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
    });
  }

  Future<void> _switchViewMode(String mode) async {
    if (_viewMode == mode) return;
    final newIndex = _modeKeys.indexOf(mode);
    if (newIndex == -1) return;
    
    setState(() {
      _viewMode = mode;
      _modeIndex = newIndex;
      _applyDateRangeFromSelected();
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final transactionsState = context.read<TransactionsState>();
      transactionsState.refreshForAccountWithDateRange(
        accountId: widget.accountId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
    });
  }

  Future<void> _openDatePicker() async {
    DateTime? picked;
    
    if (_viewMode == 'daily') {
      // Use standard date picker for daily view
      picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
    } else if (_viewMode == 'monthly') {
      // Use custom month picker for monthly view
      picked = await _showMonthPicker(
        context: context,
        initialDate: _selectedDate,
      );
    } else {
      picked = await _showYearPicker(
        context: context,
        initialDate: _selectedDate,
      );
    }

    if (picked != null) {
      DateTime target;
      if (_viewMode == 'daily') {
        target = DateTime(picked.year, picked.month, picked.day);
      } else if (_viewMode == 'monthly') {
        target = _clampDate(picked.year, picked.month, _selectedDate.day);
      } else {
        target = _clampDate(picked.year, _selectedDate.month, _selectedDate.day);
      }

      setState(() {
        _applyDateRangeFromSelected(newSelected: target);
      });
      
      // Use addPostFrameCallback to ensure state changes happen after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final transactionsState = context.read<TransactionsState>();
        transactionsState.refreshForAccountWithDateRange(
          accountId: widget.accountId,
          dateFrom: _dateFrom,
          dateTo: _dateTo,
        );
      });
    }
  }


  Future<DateTime?> _showMonthPicker({
    required BuildContext context,
    required DateTime initialDate,
  }) async {
    int selectedYear = initialDate.year;
    int selectedMonth = initialDate.month;

    return showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text('Select Month', style: Theme.of(context).textTheme.titleMedium),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                width: double.maxFinite,
                height: 360,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_left),
                          onPressed: () {
                            setState(() {
                              selectedYear--;
                            });
                          },
                        ),
                        Text(
                          '$selectedYear',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_right),
                          onPressed: () {
                            setState(() {
                              selectedYear++;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: GridView.builder(
                        padding: EdgeInsets.zero,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.4,
                        ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          final month = index + 1;
                          final monthNames = [
                            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                          ];
                          final isSelected = month == selectedMonth;
                          
                          return GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop(DateTime(selectedYear, month, 1));
                            },
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  monthNames[index],
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.onPrimary
                                        : Theme.of(context).colorScheme.onSurface,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        );
      },
    );
  }

  Future<DateTime?> _showYearPicker({
    required BuildContext context,
    required DateTime initialDate,
  }) async {
    final first = DateTime(2000);
    final last = DateTime(2100);
    return showDialog<DateTime>(
      context: context,
      builder: (context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text('Select Year', style: Theme.of(context).textTheme.titleMedium),
          content: SizedBox(
            width: double.maxFinite,
            height: 320,
            child: YearPicker(
              firstDate: first,
              lastDate: last,
              selectedDate: DateTime(initialDate.year),
              onChanged: (date) {
                Navigator.of(context).pop(DateTime(date.year, 1, 1));
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        );
      },
    );
  }

  String _formatDateRange() {
    if (_dateFrom == null || _dateTo == null) {
      return '';
    }

    if (_viewMode == 'daily') {
      return DateFormat('d MMMM yyyy').format(_dateFrom!);
    } else if (_viewMode == 'monthly') {
      return DateFormat('MMMM yyyy').format(_dateFrom!);
    } else {
      return DateFormat('yyyy').format(_dateFrom!);
    }
  }

  Future<void> _onFabPressed() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TransactionDetailPage(
          transactionId: null,
          initialType: 'EXPENSE', // default tab
          initialAccountId: widget.accountId,
          initialAccountName: widget.accountName,
        ),
      ),
    );

    if (created == true) {
      _hasChanged = true; // mark that something changed
      
      // Use addPostFrameCallback to ensure state changes happen after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refresh();   // refresh this page list
        // Refresh accounts state to update account balances
        if (mounted) {
          final accountsState = context.read<AccountsState>();
          accountsState.refresh();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // when user presses system back
        Navigator.of(context).pop(_hasChanged);
        return false;
      },
      child: Scaffold(
        appBar: widget.showAppBar
            ? AppBar(
                elevation: 0,
                centerTitle: true,
                titleSpacing: 0,
                backgroundColor: Theme.of(context).colorScheme.surface,
                leadingWidth: widget.accountId.isNotEmpty ? 110 : 72,
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.accountId.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        onPressed: () {
                          Navigator.of(context).pop(_hasChanged);
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.search_rounded),
                      tooltip: 'Search transactions',
                      onPressed: () => _showComingSoon('Search will be available soon'),
                    ),
                  ],
                ),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Transactions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (widget.accountId.isNotEmpty &&
                        widget.accountName.isNotEmpty)
                      Text(
                        widget.accountName,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                      ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.tune_rounded),
                    tooltip: 'Filter transactions',
                    onPressed: () => _showComingSoon('Filter panel coming soon'),
                  ),
                ],
              )
            : null,
        floatingActionButton: FloatingActionButton(
          heroTag: 'fab-add-transaction',
          onPressed: _onFabPressed,
          child: const Icon(Icons.add),
        ),
        body: Consumer<TransactionsState>(
          builder: (context, transactionsState, child) {
            if (transactionsState.isLoading &&
                !transactionsState.hasData) {
              return const AppLoading();
            }

            if (transactionsState.error != null &&
                !transactionsState.hasData) {
              return AppError(
                message: 'Error: ${transactionsState.error}',
                onRetry: _refresh,
              );
            }

            final txs = List<TransactionModel>.from(
              transactionsState.transactions,
            )..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (txs.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: _handleHorizontalDragEnd,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    children: [
                      _buildTopSection(0, 0, 0),
                      const SizedBox(height: 12),
                      _buildEmptyState(),
                    ],
                  ),
                ),
              );
            }

            double deposit = 0;
            double withdrawal = 0;
            for (final t in txs) {
              if (t.type == 'INCOME') {
                deposit += t.amount.abs();
              } else if (t.type == 'EXPENSE') {
                withdrawal += t.amount.abs();
              }
            }
            final total = deposit - withdrawal;

            final Map<String, List<TransactionModel>> byDate = {};
            for (final t in txs) {
              final key =
                  '${t.date.year}-${_two(t.date.month)}-${_two(t.date.day)}';
              byDate.putIfAbsent(key, () => []).add(t);
            }

            for (final dateKey in byDate.keys) {
              byDate[dateKey]!.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            }

            final sortedKeys = byDate.keys.toList()
              ..sort((a, b) => b.compareTo(a));

            return RefreshIndicator(
              onRefresh: _refresh,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: _handleHorizontalDragEnd,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  children: [
                    _buildTopSection(deposit, withdrawal, total),
                    const SizedBox(height: 4),
                    ...sortedKeys.map(
                      (dateKey) => _buildDateSection(dateKey, byDate[dateKey]!),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDateRangeRow() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModeTabs(theme),
        const SizedBox(height: 2),
        Row(
          children: [
            _buildDateNavButton(
              '<',
              () => _navigateDateRange(forward: false),
            ),
            Expanded(
              child: GestureDetector(
                onTap: _openDatePicker,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    _formatDateRange(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            _buildDateNavButton(
              '>',
              () => _navigateDateRange(forward: true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeTabs(ThemeData theme) {
    final Color highlight = Colors.redAccent;
    final Color idle =
        theme.textTheme.bodySmall?.color?.withOpacity(0.6) ?? Colors.grey;

    return Row(
      children: _modeKeys.map((key) {
        final isActive = _modeKeys[_modeIndex] == key;
        return Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _handleTabTap(key),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _tabLabels[key] ?? '',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? highlight : idle,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 3,
                    decoration: BoxDecoration(
                      color: isActive ? highlight : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateNavButton(String label, VoidCallback onPressed) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface,
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
      ),
      child: Text(
        label,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTopSection(double income, double expense, double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDateRangeRow(),
        const SizedBox(height: 2),
        _buildSummaryRow(income, expense, total),
      ],
    );
  }

  Widget _buildSummaryRow(double income, double expense, double total) {
    return Row(
      children: [
        _summaryStat('Income', income, Colors.blueAccent),
        _summaryDivider(),
        _summaryStat(
          'Expenses',
          expense,
          Colors.redAccent,
          compactValue: true,
        ),
        _summaryDivider(),
        _summaryStat(
          'Total',
          total,
          total >= 0 ? Colors.blueAccent : Colors.redAccent,
        ),
      ],
    );
  }

  Widget _summaryStat(String label, double amount, Color color,
      {bool compactValue = false}) {
    final theme = Theme.of(context);
    final double? fontSize = compactValue
        ? (theme.textTheme.titleSmall?.fontSize ?? 14) - 2
        : theme.textTheme.titleSmall?.fontSize;
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.6) ??
                  Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            MoneyFormatter.formatIDR(amount),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: fontSize,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Theme.of(context).dividerColor.withOpacity(0.3),
    );
  }

  Widget _buildDateSection(String dateKey, List<TransactionModel> txs) {
    final theme = Theme.of(context);
    final dateParts = dateKey.split('-');
    final date = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );
    final income = txs.where((t) => t.type == 'INCOME').fold<double>(
          0,
          (sum, t) => sum + t.amount.abs(),
        );
    final expense = txs.where((t) => t.type == 'EXPENSE').fold<double>(
          0,
          (sum, t) => sum + t.amount.abs(),
        );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.3),
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDayBadge(date),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _dayAmountTile(
                          'Income',
                          income,
                          Colors.blueAccent,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _dayAmountTile(
                          'Expenses',
                          expense,
                          Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...txs.map(_buildTransactionTile),
        ],
      ),
    );
  }

  Widget _buildDayBadge(DateTime date) {
    final theme = Theme.of(context);
    final String dayNumber = DateFormat('d').format(date);
    final String monthYear = DateFormat('MM/yyyy').format(date);
    final String weekday = DateFormat('EEE').format(date);
    final Color badgeColor = _weekdayBadgeColor(date.weekday);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              dayNumber,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                weekday,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: badgeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          monthYear,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.6) ??
                Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _dayAmountTile(String label, double amount, Color color) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7) ??
                Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            MoneyFormatter.formatIDR(amount),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Color _weekdayBadgeColor(int weekday) {
    if (weekday == DateTime.sunday) {
      return Colors.redAccent;
    }
    if (weekday == DateTime.saturday) {
      return Colors.deepPurpleAccent;
    }
    return Colors.grey;
  }


  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          Icons.inbox_outlined,
          size: 48,
          color: theme.disabledColor.withOpacity(0.8),
        ),
        const SizedBox(height: 12),
        Text(
          'No transactions for this period.',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Pull to refresh or pick another date range.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(TransactionModel t) {
    final theme = Theme.of(context);
    final isExpense = t.type == 'EXPENSE';
    final isTransfer = t.transferGroupId != null;
    final bool transferIn = isTransfer ? t.amount >= 0 : false;
    final Color accent = isTransfer
        ? (transferIn ? Colors.blueAccent : Colors.redAccent)
        : (isExpense ? Colors.redAccent : Colors.blueAccent);
    final IconData icon = isTransfer
        ? (transferIn
            ? Icons.call_received_rounded
            : Icons.call_made_rounded)
        : (isExpense
            ? Icons.local_mall_outlined
            : Icons.arrow_downward_rounded);
    final double amountValue = t.amount.abs();
    final title = t.categoryName.isNotEmpty
        ? t.categoryName
        : (isTransfer ? 'Transfer' : 'General');

    final detailParts = <String>[];
    if (t.description.isNotEmpty) {
      detailParts.add(t.description);
    }
    if (widget.accountId.isEmpty || widget.accountId != t.accountId) {
      detailParts.add(t.accountName);
    }
    if (detailParts.isEmpty) {
      detailParts.add(t.accountName);
    }
    final detailText = detailParts.join(' - ');
    final meta = isTransfer
        ? (transferIn ? 'Transfer In' : 'Transfer Out')
        : (isExpense ? 'Expense' : 'Income');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => TransactionDetailPage(
              transactionId: t.id,
              initialType: t.type,
              initialAccountId: t.accountId,
              initialAccountName: t.accountName,
              initialCategoryId: t.categoryId,
              initialCategoryName: t.categoryName,
            ),
          ),
        );

        if (changed == true) {
          _hasChanged = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _refresh();
            if (mounted) {
              final accountsState = context.read<AccountsState>();
              accountsState.refresh();
            }
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(0.15),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detailText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    MoneyFormatter.formatIDR(amountValue),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.6) ??
                        Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  static String _two(int v) => v.toString().padLeft(2, '0');
}
