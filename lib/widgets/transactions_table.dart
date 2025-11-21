import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../utils/money_formatter.dart';
import '../state/transactions_state.dart';

class TransactionsTable extends StatefulWidget {
  const TransactionsTable({super.key});

  @override
  State<TransactionsTable> createState() => _TransactionsTableState();
}

class _TransactionsTableState extends State<TransactionsTable> {
  @override
  void initState() {
    super.initState();
    // Load transactions using TransactionsState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final transactionsState = context.read<TransactionsState>();
      transactionsState.load(); // initial load (cached or fresh)
    });
  }

  void _setFilter(String type) {
    final transactionsState = context.read<TransactionsState>();
    transactionsState.setFilter(type);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionsState>(
      builder: (context, transactionsState, child) {
        if (transactionsState.isLoading && !transactionsState.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (transactionsState.error != null && !transactionsState.hasData) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error: ${transactionsState.error}'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => transactionsState.refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final filtered = transactionsState.filteredTransactions;

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
                onRefresh: () => transactionsState.refresh(),
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
    return Consumer<TransactionsState>(
      builder: (context, transactionsState, child) {
        return Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: transactionsState.typeFilter == 'ALL',
              onSelected: (_) => _setFilter('ALL'),
            ),
            ChoiceChip(
              label: const Text('Income'),
              selected: transactionsState.typeFilter == 'INCOME',
              onSelected: (_) => _setFilter('INCOME'),
            ),
            ChoiceChip(
              label: const Text('Expense'),
              selected: transactionsState.typeFilter == 'EXPENSE',
              onSelected: (_) => _setFilter('EXPENSE'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}
