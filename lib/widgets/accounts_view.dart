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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error: ${accountsState.error}'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => accountsState.refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final groups = accountsState.groups;

        if (groups.isEmpty) {
          return RefreshIndicator(
            onRefresh: accountsState.refresh,
            child: ListView(
              children: const [
                SizedBox(height: 80),
                Center(child: Text('No accounts yet.')),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: accountsState.refresh,
          child: ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Group header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            group.kind,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Content: editable reorderable list vs normal list
                      isEditMode
                          ? _buildEditableAccountsList(
                              context,
                              accountsState,
                              group,
                            )
                          : _buildNormalAccountsList(context, group),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEditableAccountsList(
    BuildContext context,
    AccountsState accountsState,
    AccountGroup group,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(
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
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.drag_handle, color: Colors.grey),
              title: Text(
                acc.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNormalAccountsList(
    BuildContext context,
    AccountGroup group,
  ) {
    return Column(
      children: group.accounts.map((acc) {
        final balanceText = MoneyFormatter.formatIDR(acc.balance);

        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            acc.name,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Text(
            balanceText,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          onTap: () async {
            final changed = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => AccountTransactionsPage(
                  accountId: acc.id,
                  accountName: acc.name,
                  currency: acc.currency,
                  currentBalance: acc.balance,
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
