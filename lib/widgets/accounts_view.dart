// lib/widgets/accounts_view.dart
import 'package:flutter/material.dart';
import '../services/account_group_service.dart';
import '../services/account_service.dart';
import '../models/account_group.dart';
import '../pages/account_transactions_page.dart';
import '../pages/account_form_page.dart';
import '../utils/money_formatter.dart';
import '../utils/refresh_notifier.dart';

class AccountsView extends StatefulWidget {
  final int refreshToken;          // used to trigger refetch from HomePage
  final VoidCallback? onDataChanged; // called when something changes in child pages
  final bool isEditMode;           // controls whether we're in edit mode

  const AccountsView({
    super.key,
    required this.refreshToken,
    this.onDataChanged,
    this.isEditMode = false,
  });

  @override
  State<AccountsView> createState() => _AccountsViewState();
}

class _AccountsViewState extends State<AccountsView> {
  final AccountGroupService _groupService = AccountGroupService();
  final AccountService _accountService = AccountService();
  late Future<List<AccountGroup>> _future;
  final RefreshNotifier _refreshNotifier = RefreshNotifier.instance;

  @override
  void initState() {
    super.initState();
    _future = _groupService.fetchAccountGroups(useCache: false); // Don't use cache when initializing to ensure fresh data
    _refreshNotifier.addListener(_onRefreshNotifierChanged);
  }

  @override
  void dispose() {
    _refreshNotifier.removeListener(_onRefreshNotifierChanged);
    super.dispose();
  }

  void _onRefreshNotifierChanged() {
    if (mounted) {
      _refresh();
    }
  }

  @override
  void didUpdateWidget(covariant AccountsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // when HomePage bumps refreshToken, refetch account groups
    if (oldWidget.refreshToken != widget.refreshToken) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _groupService.fetchAccountGroups(useCache: false);
    });
  }

  void _reorderAccounts(String groupId, int oldIndex, int newIndex) {
    setState(() {
      // Update the future to trigger a rebuild with reordered data
      _future = _future.then((groups) {
        // Find the group with matching ID
        final groupIndex = groups.indexWhere((g) => g.id == groupId);
        if (groupIndex == -1) return groups;
        
        final group = groups[groupIndex];
        final List<AccountModel> accounts = List.from(group.accounts);
        
        // Reorder the accounts list
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }
        final AccountModel account = accounts.removeAt(oldIndex);
        accounts.insert(newIndex, account);
        
        // Create a new group with reordered accounts
        final updatedGroup = AccountGroup(
          id: group.id,
          name: group.name,
          kind: group.kind,
          accounts: accounts,
        );
        
        // Update the groups list with the updated group
        final List<AccountGroup> updatedGroups = List.from(groups);
        updatedGroups[groupIndex] = updatedGroup;
        
        return updatedGroups;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AccountGroup>>(
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

        final groups = snapshot.data ?? [];

        if (groups.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: const [
                SizedBox(height: 80),
                Center(child: Text('No accounts yet.')),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      widget.isEditMode
                          ? Theme(
                              data: Theme.of(context).copyWith(
                                canvasColor: Colors.transparent,
                              ),
                              child: ReorderableListView(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                onReorder: (oldIndex, newIndex) {
                                  _reorderAccounts(group.id, oldIndex, newIndex);
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
                                                widget.onDataChanged?.call();
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
                            )
                          : Column(
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
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
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
                                  onTap: () async {
                                    final changed =
                                        await Navigator.of(context).push<bool>(
                                      MaterialPageRoute(
                                        builder: (_) => AccountTransactionsPage(
                                          accountId: acc.id,
                                          accountName: acc.name,
                                          currency: acc.currency,
                                          currentBalance: acc.balance,
                                        ),
                                      ),
                                    );

                                    if (changed == true) {
                                      // tell HomePage that something changed
                                      widget.onDataChanged?.call();
                                    }
                                  },
                                );
                              }).toList(),
                            ),
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
}
