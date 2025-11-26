import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account_group.dart';
import '../pages/account_transactions_page.dart';
import '../pages/account_form_page.dart';
import '../utils/money_formatter.dart';
import '../state/accounts_state.dart';

class AccountsView extends StatelessWidget {
  final bool isEditMode;
  final bool showSummaryBar;
  final bool compactLayout;

  const AccountsView({
    super.key,
    this.isEditMode = false,
    this.showSummaryBar = true,
    this.compactLayout = false,
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

        final groups = accountsState.groups
            .where((g) => g.accounts.isNotEmpty)
            .toList();

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
            padding: compactLayout
                ? const EdgeInsets.only(bottom: 40)
                : const EdgeInsets.only(bottom: 80),
            itemCount: groups.length + (showSummaryBar ? 1 : 0),
            itemBuilder: (context, index) {
              if (showSummaryBar && index == 0) {
                return _AccountsSummaryBar(groups: groups);
              }

              final groupIndex = showSummaryBar ? index - 1 : index;
              final group = groups[groupIndex];
              return _AccountGroupSection(
                group: group,
                isEditMode: isEditMode,
                compactLayout: compactLayout,
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

    for (final g in groups) {
      final groupTotal = g.accounts
          .where((a) => a.includeInTotals && a.scope.toUpperCase() == 'HOUSEHOLD',)
          .fold<double>(0, (sum, a) => sum + a.balance);
      if (g.kind.toUpperCase() == 'ASSET' ||
          g.kind.toUpperCase() == 'BANK_ACCOUNTS' ||
          g.kind.toUpperCase() == 'CASH' ||
          g.kind.toUpperCase() == 'INVESTMENTS') {
        assets += groupTotal;
      } else if (g.kind.toUpperCase() == 'LIABILITY' ||
          g.kind.toUpperCase() == 'CREDIT_CARDS' ||
          g.kind.toUpperCase() == 'LOANS') {
        liabilities += groupTotal;
      }
    }

    final total = assets + liabilities;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      color: Colors.transparent,
      child: Row(
        children: [
          _SummaryItem(
            label: 'Assets',
            amount: assets,
            color: theme.colorScheme.tertiary,
          ),
          _SummaryItem(
            label: 'Liabilities',
            amount: liabilities,
            color: theme.colorScheme.error,
          ),
          _SummaryItem(
            label: 'Total',
            amount: total,
            color: theme.colorScheme.secondary,
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
  final bool compactLayout;

  const _AccountGroupSection({
    required this.group,
    required this.isEditMode,
    required this.compactLayout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final groupTotal = group.accounts
        .where((a) => a.includeInTotals)
        .fold<double>(0, (sum, a) => sum + a.balance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header row (like "Bank Jago   Rp 76,346,426.00")
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compactLayout ? 14 : 16,
            vertical: compactLayout ? 8 : 10,
          ),
          color: theme.colorScheme.surface,
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
                  color: theme.colorScheme.secondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Content: editable reorderable list vs normal list
        isEditMode
            ? _EditableAccountsList(group: group, compactLayout: compactLayout)
            : _NormalAccountsList(group: group, compactLayout: compactLayout),
      ],
    );
  }
}

class _NormalAccountsList extends StatelessWidget {
  final AccountGroup group;
  final bool compactLayout;

  const _NormalAccountsList({required this.group, required this.compactLayout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: group.accounts.map((acc) {
        final balanceText = MoneyFormatter.formatIDR(acc.balance);
        final isExcluded = !acc.includeInTotals;
        final titleColor = isExcluded
            ? theme.colorScheme.onSurface.withOpacity(0.4)
            : theme.colorScheme.onSurface;
        final balanceColor = isExcluded
            ? theme.colorScheme.onSurfaceVariant.withOpacity(0.7)
            : theme.colorScheme.tertiary;

        return Column(
          children: [
            Container(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: compactLayout ? 12 : 16,
                  vertical: compactLayout ? 0 : 4,
                ),
                title: Text(
                  acc.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: titleColor,
                  ),
                ),
                trailing: Text(
                  balanceText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: balanceColor,
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
              ),
            ),
            Divider(height: 0, thickness: 0.5, indent: compactLayout ? 0 : 0),
          ],
        );
      }).toList(),
    );
  }
}

class _EditableAccountsList extends StatelessWidget {
  final AccountGroup group;
  final bool compactLayout;

  const _EditableAccountsList({
    required this.group,
    required this.compactLayout,
  });

  @override
  Widget build(BuildContext context) {
    final accountsState = context.read<AccountsState>();
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(canvasColor: Colors.transparent),
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
            child: Column(
              children: [
                Container(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: compactLayout ? 12 : 16,
                      vertical: compactLayout ? 0 : 4,
                    ),
                    leading: const Icon(Icons.drag_handle, color: Colors.grey),
                    title: Text(
                      acc.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: acc.includeInTotals
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () async {
                            final changed = await Navigator.of(context)
                                .push<bool>(
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
                            color: acc.includeInTotals
                                ? theme.colorScheme.tertiary
                                : theme.colorScheme.onSurfaceVariant
                                      .withOpacity(0.7),
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
                ),
                Divider(
                  height: 0,
                  thickness: 0.5,
                  indent: compactLayout ? 0 : 0,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
