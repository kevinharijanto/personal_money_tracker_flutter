import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account_group.dart';
import '../pages/account_transactions_page.dart';
import '../pages/account_form_page.dart';
import '../utils/money_formatter.dart';
import '../state/accounts_state.dart';

class AccountsView extends StatelessWidget {
  final bool isEditMode;

  const AccountsView({
    super.key,
    this.isEditMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AccountsState>(
      builder: (context, accountsState, child) {
        if (accountsState.isLoading && !accountsState.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (accountsState.error != null && !accountsState.hasData) {
          return Center(
            child: Text(
              'Error: ${accountsState.error}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        final groups = accountsState.groups;

        if (groups.isEmpty) {
          return RefreshIndicator(
            onRefresh: accountsState.refresh,
            child: ListView(
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Text(
                    'No accounts yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: accountsState.refresh,
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: groups.length + 1, // +1 for summary header
            itemBuilder: (context, index) {
              if (index == 0) {
                // Top summary bar (Assets | Liabilities | Total)
                return _AccountsSummaryBar(groups: groups);
              }

              final group = groups[index - 1];
              return _AccountGroupSection(
                group: group,
                isEditMode: isEditMode,
              );
            },
          ),
        );
      },
    );
  }
}

/// Top bar: Assets | Liabilities | Total
class _AccountsSummaryBar extends StatelessWidget {
  final List<AccountGroup> groups;

  const _AccountsSummaryBar({required this.groups});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    double assets = 0;
    double liabilities = 0;

    // Debug print to see what data we're working with
    debugPrint('=== Accounts Summary Debug ===');
    debugPrint('Number of groups: ${groups.length}');
    
    for (final g in groups) {
      final groupTotal = g.accounts.fold<double>(
        0,
        (sum, a) => sum + a.balance,
      );
      debugPrint('Group: ${g.name}, Kind: "${g.kind}", Total: $groupTotal, Accounts: ${g.accounts.length}');
      for (final account in g.accounts) {
        debugPrint('  Account: ${account.name}, Balance: ${account.balance}');
      }
      
      if (g.kind.toUpperCase() == 'ASSET' || g.kind.toUpperCase() == 'BANK_ACCOUNTS' || g.kind.toUpperCase() == 'CASH' || g.kind.toUpperCase() == 'INVESTMENTS') {
        assets += groupTotal;
        debugPrint('  -> Added to assets: $groupTotal');
      } else if (g.kind.toUpperCase() == 'LIABILITY' || g.kind.toUpperCase() == 'CREDIT_CARDS' || g.kind.toUpperCase() == 'LOANS') {
        liabilities += groupTotal;
        debugPrint('  -> Added to liabilities: $groupTotal');
      } else {
        debugPrint('  -> Group kind "${g.kind}" does not match ASSET or LIABILITY categories');
      }
    }

    debugPrint('Final Assets: $assets, Liabilities: $liabilities, Total: ${assets + liabilities}');
    debugPrint('=== End Debug ===');

    final total = assets + liabilities;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
      ),
      child: Row(
        children: [
          _SummaryItem(
            label: 'Assets',
            amount: assets,
            color: Colors.blueAccent,
          ),
          _SummaryItem(
            label: 'Liabilities',
            amount: liabilities,
            color: Colors.redAccent,
          ),
          _SummaryItem(
            label: 'Total',
            amount: total,
            color: theme.colorScheme.onSurface,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            MoneyFormatter.formatIDR(amount),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// A whole group: header row + accounts inside
class _AccountGroupSection extends StatelessWidget {
  final AccountGroup group;
  final bool isEditMode;

  const _AccountGroupSection({
    required this.group,
    required this.isEditMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final groupTotal = group.accounts.fold<double>(
      0,
      (sum, a) => sum + a.balance,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header row (like "Bank Jago   Rp 76,346,426.00")
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  group.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                MoneyFormatter.formatIDR(groupTotal),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Content: editable reorderable list vs normal list
        isEditMode
            ? _EditableAccountsList(group: group)
            : _NormalAccountsList(group: group),
      ],
    );
  }
}

class _NormalAccountsList extends StatelessWidget {
  final AccountGroup group;

  const _NormalAccountsList({required this.group});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: group.accounts.map((acc) {
        final balanceText = MoneyFormatter.formatIDR(acc.balance);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          title: Text(
            acc.name,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          trailing: Text(
            balanceText,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.blueAccent, // like screenshot
            ),
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () async {
            final changed = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => AccountTransactionsPage(
                  accountId: acc.id,
                  accountName: acc.name,
                  currency: acc.currency,
                  currentBalance: 0,
                  showAppBar: true,
                ),
              ),
            );

            if (changed == true) {
              final accountsState = context.read<AccountsState>();
              await accountsState.refresh();
            }
          },
        );
      }).toList(),
    );
  }
}

class _EditableAccountsList extends StatelessWidget {
  final AccountGroup group;

  const _EditableAccountsList({required this.group});

  @override
  Widget build(BuildContext context) {
    final accountsState = context.read<AccountsState>();
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
        canvasColor: Colors.transparent,
      ),
      child: ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        onReorder: (oldIndex, newIndex) {
          accountsState.reorderAccounts(group.id, oldIndex, newIndex);
        },
        children: group.accounts.asMap().entries.map((entry) {
          final index = entry.key;
          final acc = entry.value;
          final balanceText = MoneyFormatter.formatIDR(acc.balance);

          return ReorderableDragStartListener(
            key: ValueKey(acc.id),
            index: index,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: const Icon(Icons.drag_handle, color: Colors.grey),
              title: Text(
                acc.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () async {
                      final changed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => AccountFormPage(
                            account: acc,
                            groupId: group.id,
                          ),
                        ),
                      );

                      if (changed == true) {
                        await accountsState.refresh();
                      }
                    },
                  ),
                  Text(
                    balanceText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
              onTap: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => AccountTransactionsPage(
                      accountId: acc.id,
                      accountName: acc.name,
                      currency: acc.currency,
                      currentBalance: 0,
                      showAppBar: true,
                    ),
                  ),
                );

                if (changed == true) {
                  await accountsState.refresh();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
