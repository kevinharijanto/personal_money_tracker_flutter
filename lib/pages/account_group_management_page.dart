import 'package:flutter/material.dart';
import '../services/account_group_service.dart';
import '../models/account_group.dart';
import '../utils/refresh_notifier.dart';

class AccountGroupManagementPage extends StatefulWidget {
  const AccountGroupManagementPage({super.key});

  @override
  State<AccountGroupManagementPage> createState() => _AccountGroupManagementPageState();
}

class _AccountGroupManagementPageState extends State<AccountGroupManagementPage> {
  final AccountGroupService _accountGroupService = AccountGroupService();
  late Future<List<AccountGroup>> _future;
  bool _isLoading = false;

  // Predefined account group kinds
  final List<Map<String, String>> _accountKinds = [
    {'value': 'BANK_ACCOUNTS', 'label': 'Bank Accounts'},
    {'value': 'CASH', 'label': 'Cash'},
    {'value': 'CREDIT_CARDS', 'label': 'Credit Cards'},
    {'value': 'INVESTMENTS', 'label': 'Investments'},
    {'value': 'LOANS', 'label': 'Loans'},
    {'value': 'OTHER', 'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _refreshAccountGroups();
  }

  Future<void> _refreshAccountGroups() async {
    setState(() {
      _future = _accountGroupService.fetchAccountGroups();
    });
  }

  Future<void> _showAddAccountGroupDialog() async {
    final nameController = TextEditingController();
    final kindController = TextEditingController(text: _accountKinds.first['value']);
    final formKey = GlobalKey<FormState>(debugLabel: 'account_group_add_form_key');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Account Group'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a group name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: kindController.text,
                  decoration: const InputDecoration(
                    labelText: 'Group Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _accountKinds.map((kind) {
                    return DropdownMenuItem<String>(
                      value: kind['value'],
                      child: Text(kind['label']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    kindController.text = value ?? '';
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        await _accountGroupService.createAccountGroup(
          name: nameController.text.trim(),
          kind: kindController.text.trim(),
        );
        _refreshAccountGroups();
        // Trigger global refresh for accounts page
        RefreshNotifier.instance.refreshAccounts();
      } catch (e) {
        // Handle error silently
      }
    }
  }

  Future<void> _showEditAccountGroupDialog(AccountGroup accountGroup) async {
    final nameController = TextEditingController(text: accountGroup.name);
    final kindController = TextEditingController(text: accountGroup.kind);
    final formKey = GlobalKey<FormState>(debugLabel: 'account_group_edit_form_key');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Account Group'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a group name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: kindController.text,
                  decoration: const InputDecoration(
                    labelText: 'Group Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _accountKinds.map((kind) {
                    return DropdownMenuItem<String>(
                      value: kind['value'],
                      child: Text(kind['label']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    kindController.text = value ?? '';
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        await _accountGroupService.updateAccountGroup(
          groupId: accountGroup.id,
          name: nameController.text.trim(),
          kind: kindController.text.trim(),
        );
        _refreshAccountGroups();
        // Trigger global refresh for accounts page
        RefreshNotifier.instance.refreshAccounts();
      } catch (e) {
        // Handle error silently
      }
    }
  }

  Future<void> _showDeleteConfirmation(AccountGroup accountGroup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Account Group'),
          content: Text(
            'Are you sure you want to delete "${accountGroup.name}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _accountGroupService.deleteAccountGroup(accountGroup.id);
        _refreshAccountGroups();
      } catch (e) {
        // Handle error silently
      }
    }
  }

  String _getKindLabel(String kind) {
    final found = _accountKinds.firstWhere(
      (k) => k['value'] == kind,
      orElse: () => {'value': kind, 'label': kind},
    );
    return found['label'] ?? kind;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Groups'),
      ),
      body: FutureBuilder<List<AccountGroup>>(
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
                    onPressed: _refreshAccountGroups,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final accountGroups = snapshot.data ?? [];

          if (accountGroups.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'No account groups yet.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _showAddAccountGroupDialog,
                    child: const Text('Add Account Group'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshAccountGroups,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: accountGroups.length,
              itemBuilder: (context, index) {
                final accountGroup = accountGroups[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      accountGroup.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      _getKindLabel(accountGroup.kind),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showEditAccountGroupDialog(accountGroup),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _showDeleteConfirmation(accountGroup),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAccountGroupDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}