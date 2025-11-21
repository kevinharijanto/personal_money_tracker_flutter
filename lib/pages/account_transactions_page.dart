import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../pages/transaction_detail_page.dart';
import '../utils/money_formatter.dart';
import '../state/accounts_state.dart';
import '../state/transactions_state.dart';

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
  String _viewMode = 'daily'; // 'daily' or 'monthly'

  @override
  void initState() {
    super.initState();
    _initializeAndFetchTransactions();
  }

  void _initializeAndFetchTransactions() {
    // Initialize with current day for daily view
    final now = DateTime.now();
    final localNow = now.toLocal(); // Convert to local time
    if (_viewMode == 'daily') {
      _dateFrom = DateTime(localNow.year, localNow.month, localNow.day); // Today
      _dateTo = DateTime(localNow.year, localNow.month, localNow.day + 1); // Tomorrow (for API range)
    } else {
      _dateFrom = DateTime(localNow.year, localNow.month, 1);
      _dateTo = DateTime(localNow.year, localNow.month + 1, 0);
    }
    
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

  Future<void> _navigateDateRange({bool forward = true}) async {
    if (_dateFrom == null || _dateTo == null) return;
    
    DateTime newDateFrom;
    DateTime newDateTo;

    if (_viewMode == 'daily') {
      // Navigate by day (showing single day)
      final currentDay = _dateFrom!; // Use the "from" date as reference
      if (forward) {
        // Next day
        newDateFrom = DateTime(currentDay.year, currentDay.month, currentDay.day + 1);
        newDateTo = DateTime(currentDay.year, currentDay.month, currentDay.day + 2);
      } else {
        // Previous day
        newDateFrom = DateTime(currentDay.year, currentDay.month, currentDay.day - 1);
        newDateTo = DateTime(currentDay.year, currentDay.month, currentDay.day);
      }
    } else {
      // Navigate by month
      final currentFrom = _dateFrom!;
      if (forward) {
        // Next month
        newDateFrom = DateTime(currentFrom.year, currentFrom.month + 1, 1);
        newDateTo = DateTime(currentFrom.year, currentFrom.month + 2, 0);
      } else {
        // Previous month
        newDateFrom = DateTime(currentFrom.year, currentFrom.month - 1, 1);
        newDateTo = DateTime(currentFrom.year, currentFrom.month, 0);
      }
    }

    setState(() {
      _dateFrom = newDateFrom;
      _dateTo = newDateTo;
    });
    
    final transactionsState = context.read<TransactionsState>();
    await transactionsState.refreshForAccountWithDateRange(
      accountId: widget.accountId,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
  }

  Future<void> _switchViewMode(String mode) async {
    if (_viewMode == mode) return;
    
    setState(() {
      _viewMode = mode;
      final now = DateTime.now();
      final localNow = now.toLocal(); // Convert to local time
      
      if (mode == 'daily') {
        _dateFrom = DateTime(localNow.year, localNow.month, localNow.day); // Today
        _dateTo = DateTime(localNow.year, localNow.month, localNow.day + 1); // Tomorrow (for API range)
      } else {
        _dateFrom = DateTime(localNow.year, localNow.month, 1);
        _dateTo = DateTime(localNow.year, localNow.month + 1, 0);
      }
    });
    
    final transactionsState = context.read<TransactionsState>();
    await transactionsState.refreshForAccountWithDateRange(
      accountId: widget.accountId,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
  }

  String _formatDateRange() {
    if (_dateFrom == null || _dateTo == null) {
      return '';
    }

    if (_viewMode == 'daily') {
      // Format as day, month name, and year (showing the current day)
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final monthName = months[_dateFrom!.month - 1];
      return '${_dateFrom!.day} $monthName ${_dateFrom!.year}';
    } else {
      // Format as month name and year
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final monthName = months[_dateFrom!.month - 1];
      return '$monthName ${_dateFrom!.year}';
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
      await _refresh();   // refresh this page list
      // Refresh accounts state to update account balances
      if (mounted) {
        final accountsState = context.read<AccountsState>();
        await accountsState.refresh();
      }
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
        appBar: widget.showAppBar ? AppBar(
          title: Text(widget.accountName),
          leading: widget.accountId.isEmpty ? null : IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // when user presses top-left back (only for specific account)
              Navigator.of(context).pop(_hasChanged);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: () {
                // TODO: stats page
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // TODO: edit account
              },
            ),
          ],
        ) : null,
        floatingActionButton: FloatingActionButton(
          onPressed: _onFabPressed,
          child: const Icon(Icons.add),
        ),
        body: Consumer<TransactionsState>(
          builder: (context, transactionsState, child) {
            if (transactionsState.isLoading && !transactionsState.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (transactionsState.error != null && !transactionsState.hasData) {
              return Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Error: ${transactionsState.error}'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final txs = transactionsState.transactions;
            
            // Sort transactions by creation time (newest first)
            txs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (txs.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildDateRangeRow(),
                    const SizedBox(height: 12),
                    const SizedBox(height: 80),
                    const Center(child: Text('No transactions for this period.')),
                  ],
                ),
              );
            }

            // ---- summary: deposit / withdrawal / total ----
            double deposit = 0;
            double withdrawal = 0;
            for (final t in txs) {
              if (t.type == 'INCOME') {
                deposit += t.amount;
              } else if (t.type == 'EXPENSE') {
                withdrawal += t.amount.abs();
              }
            }
            final total = deposit - withdrawal;
            final balance = widget.currentBalance;

            // ---- group by date (yyyy-MM-dd) ----
            final Map<String, List<TransactionModel>> byDate = {};
            for (final t in txs) {
              final key =
                  '${t.date.year}-${_two(t.date.month)}-${_two(t.date.day)}';
              byDate.putIfAbsent(key, () => []).add(t);
            }
            
            // Sort transactions within each date by creation time (newest first)
            for (final dateKey in byDate.keys) {
              byDate[dateKey]!.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            }

            // sort dates descending
            final sortedKeys = byDate.keys.toList()
              ..sort((a, b) => b.compareTo(a));

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildDateRangeRow(), // static for now
                  const SizedBox(height: 12),
                  _buildSummaryRow(deposit, withdrawal, total, balance),
                  const SizedBox(height: 16),
                  // For now, only "Daily" view – tabs can come later
                  ...sortedKeys.map((dateKey) {
                    final list = byDate[dateKey]!;
                    final dateTotal = list.fold<double>(
                      0,
                      (sum, t) => sum + t.amount,
                    );
                    return _buildDateSection(dateKey, dateTotal, list);
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDateRangeRow() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      children: [
        // Tabs for Daily/Monthly view
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _switchViewMode('daily'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _viewMode == 'daily'
                          ? (isDark ? Colors.grey.shade700 : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Daily',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: _viewMode == 'daily' ? FontWeight.w600 : FontWeight.w400,
                        color: _viewMode == 'daily'
                            ? theme.colorScheme.primary
                            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _switchViewMode('monthly'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _viewMode == 'monthly'
                          ? (isDark ? Colors.grey.shade700 : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Monthly',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: _viewMode == 'monthly' ? FontWeight.w600 : FontWeight.w400,
                        color: _viewMode == 'monthly'
                            ? theme.colorScheme.primary
                            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Date navigation row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: _viewMode == 'daily' ? 'Previous day' : 'Previous month',
              onPressed: () => _navigateDateRange(forward: false),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 1,
                ),
              ),
              child: Text(
                _formatDateRange(),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: _viewMode == 'daily' ? 'Next day' : 'Next month',
              onPressed: () => _navigateDateRange(forward: true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
      double deposit, double withdrawal, double total, double balance) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _summaryItem('Deposit', MoneyFormatter.formatIDR(deposit), color: Colors.blue),
            _summaryItem('Withdrawal', MoneyFormatter.formatIDR(withdrawal), color: Colors.red),
            _summaryItem('Total', MoneyFormatter.formatIDR(total)),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, {Color? color}) {
    // Determine font size based on value length
    double fontSize = 13;
    if (value.length > 10) {
      fontSize = 11;
    } else if (value.length > 8) {
      fontSize = 12;
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildDateSection(
      String dateKey, double dateTotal, List<TransactionModel> txs) {
    final dtParts = dateKey.split('-');
    final yyyy = dtParts[0];
    final mm = dtParts[1];
    final dd = dtParts[2];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$dd/$mm/$yyyy',
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              MoneyFormatter.formatIDR(dateTotal),
              style: TextStyle(
                color: dateTotal >= 0 ? Colors.blue : Colors.red,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...txs.map(_buildTransactionTile),
      ],
    );
  }

  Widget _buildTransactionTile(TransactionModel t) {
    final isExpense = t.type == 'EXPENSE';
    final amountText = MoneyFormatter.formatIDR(t.amount);

    final title =
        (t.description.isNotEmpty ? t.description : t.categoryName);

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.circle, size: 10),
      title: Text(title),
      subtitle: Text(
        widget.accountId.isEmpty
            ? '${t.accountName} • ${t.categoryName}'
            : t.categoryName,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: Text(
        amountText,
        style: TextStyle(
          color: isExpense ? Colors.red : Colors.blue,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
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
          _hasChanged = true; // mark changed
          _refresh();
          // Refresh accounts state to update account balances
          if (mounted) {
            final accountsState = context.read<AccountsState>();
            await accountsState.refresh();
          }
        }
      },
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
