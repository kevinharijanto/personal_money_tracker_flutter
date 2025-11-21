import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../services/household_service.dart';
import '../storage/auth_storage.dart';
import '../utils/money_formatter.dart';

class TransactionsTable extends StatefulWidget {
  const TransactionsTable({super.key});

  @override
  State<TransactionsTable> createState() => _TransactionsTableState();
}

class _TransactionsTableState extends State<TransactionsTable> {
  late Future<List<TransactionModel>> _future;
  final TransactionService _txnService = TransactionService();
  final HouseholdService _householdService = HouseholdService();
  String _typeFilter = 'ALL'; // ALL, INCOME, EXPENSE

  @override
  void initState() {
    super.initState();
    _future = _load(useCache: false); // Don't use cache when initializing to ensure fresh data
  }

  Future<List<TransactionModel>> _load({bool useCache = true}) async {
    // 1. Ensure we have a householdId
    var householdId = await AuthStorage.getHouseholdId();
    if (householdId == null || householdId.isEmpty) {
      final households = await _householdService.fetchHouseholds();
      if (households.isEmpty) {
        throw Exception('No households found for this user');
      }
      // For now, just pick the first one
      householdId = households.first.id;
      await AuthStorage.setHouseholdId(householdId);
    }

    // 2. Now we can safely fetch transactions (ApiClient will include X-Household-ID)
    return _txnService.fetchTransactions(useCache: useCache);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load(useCache: false);
    });
  }

  void _setFilter(String type) {
    setState(() {
      _typeFilter = type;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TransactionModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final allData = snapshot.data ?? [];

        // Sort all transactions by creation time (newest first)
        allData.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final filtered = allData.where((tx) {
          if (_typeFilter == 'ALL') return true;
          return tx.type == _typeFilter;
        }).toList();

        if (filtered.isEmpty) {
          return Column(
            children: [
              _buildFilterRow(),
              const SizedBox(height: 16),
              const Expanded(
                child: Center(child: Text('No transactions found.')),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterRow(),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Account')),
                        DataColumn(label: Text('Category')),
                        DataColumn(label: Text('Amount')),
                      ],
                      rows: filtered.map((tx) {
                        final isExpense = tx.type == 'EXPENSE';
                        final amountText = MoneyFormatter.formatIDR(tx.amount);

                        return DataRow(
                          cells: [
                            DataCell(Text(_formatDate(tx.date))),
                            DataCell(Text(tx.type)),
                            DataCell(Text(tx.accountName)),
                            DataCell(Text(tx.categoryName)),
                            DataCell(
                              Text(
                                amountText,
                                style: TextStyle(
                                  color: isExpense ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterRow() {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('All'),
          selected: _typeFilter == 'ALL',
          onSelected: (_) => _setFilter('ALL'),
        ),
        ChoiceChip(
          label: const Text('Income'),
          selected: _typeFilter == 'INCOME',
          onSelected: (_) => _setFilter('INCOME'),
        ),
        ChoiceChip(
          label: const Text('Expense'),
          selected: _typeFilter == 'EXPENSE',
          onSelected: (_) => _setFilter('EXPENSE'),
        ),
      ],
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
