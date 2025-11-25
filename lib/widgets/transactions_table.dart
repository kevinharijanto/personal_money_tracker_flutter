// inside widgets/transactions_table.dart (or a new file)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/transactions_state.dart';
import '../models/transaction.dart';
import '../utils/money_formatter.dart';

class TransactionsTable extends StatelessWidget {
  const TransactionsTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionsState>(
      builder: (context, txState, child) {
        if (txState.isLoading && !txState.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (txState.error != null && !txState.hasData) {
          return Center(
            child: Text(
              'Error: ${txState.error}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        final transactions = txState.filteredTransactions;
        if (transactions.isEmpty) {
          return Center(
            child: Text(
              'No transactions',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        // Simple vertical list for now; we can group by date later
        return RefreshIndicator(
          onRefresh: () => txState.refresh(),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return _TransactionRow(tx: tx);
            },
          ),
        );
      },
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final TransactionModel tx;

  const _TransactionRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpense = tx.type == 'EXPENSE';
    final isIncome = tx.type == 'INCOME';
    final isTransfer = tx.type == 'TRANSFER';

    final amountText = MoneyFormatter.formatIDR(tx.amount);

    Color amountColor;
    if (isExpense) {
      amountColor = theme.colorScheme.error;
    } else if (isIncome) {
      amountColor = theme.colorScheme.tertiary;
    } else {
      amountColor = theme.colorScheme.onSurface; // transfer
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _buildCategoryIcon(theme),
      title: Text(
        tx.categoryName.isNotEmpty ? tx.categoryName : (isTransfer ? 'Transfer' : 'No category'),
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        tx.accountName,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            amountText,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: amountColor,
            ),
          ),
          // if (tx.balanceAfter != null) // optional, if you ever add running balance
          //   Text(
          //     MoneyFormatter.formatIDR(tx.balanceAfter!),
          //     style: TextStyle(
          //       fontSize: 11,
          //       color: theme.colorScheme.onSurface.withOpacity(0.6),
          //     ),
          //   ),
        ],
      ),
      onTap: () {
        // open TransactionDetailPage for editing if you want
      },
    );
  }

  Widget _buildCategoryIcon(ThemeData theme) {
    // Placeholder: later we can map category to emoji / icon.
    final isTransfer = tx.type == 'TRANSFER';
    final bgColor = isTransfer
        ? theme.colorScheme.primary.withOpacity(0.15)
        : theme.colorScheme.surfaceVariant;

    final icon = isTransfer ? Icons.swap_horiz : Icons.category;

    return CircleAvatar(
      radius: 16,
      backgroundColor: bgColor,
      child: Icon(
        icon,
        size: 18,
        color: theme.colorScheme.onSurface.withOpacity(0.8),
      ),
    );
  }
}
