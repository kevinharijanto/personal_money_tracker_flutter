import 'package:flutter/material.dart';
import '../models/account_group.dart';
import '../services/account_service.dart';
import '../services/account_group_service.dart';
import '../storage/auth_storage.dart';
import '../utils/refresh_notifier.dart';

class AccountFormPage extends StatefulWidget {
  final AccountModel? account; // null for creating new account
  final String? groupId; // required for new account

  const AccountFormPage({
    super.key,
    this.account,
    this.groupId,
  });

  @override
  State<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends State<AccountFormPage> {
  final _formKey = GlobalKey<FormState>(debugLabel: 'account_form_key');
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final AccountService _accountService = AccountService();
  final AccountGroupService _accountGroupService = AccountGroupService();
  final RefreshNotifier _refreshNotifier = RefreshNotifier.instance;
  
  String? _selectedGroupId;
  String _selectedCurrency = 'IDR';
  bool _isArchived = false;
  List<AccountGroup> _accountGroups = [];
  bool _isLoading = false;
  bool _isLoadingGroups = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Set initial values if editing
    if (widget.account != null) {
      _nameController.text = widget.account!.name;
      _balanceController.text = widget.account!.balance.toString();
      _selectedCurrency = widget.account!.currency;
      _isArchived = widget.account!.isArchived;
      _selectedGroupId = widget.groupId; // This would need to be passed when editing
    } else if (widget.groupId != null) {
      _selectedGroupId = widget.groupId;
    }

    // Load account groups
    try {
      final groups = await _accountGroupService.fetchAccountGroups(useCache: true);
      setState(() {
        _accountGroups = groups;
        _isLoadingGroups = false;
        // If no group is selected and we have groups, select the first one
        if (_selectedGroupId == null && groups.isNotEmpty) {
          _selectedGroupId = groups.first.id;
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingGroups = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load account groups: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = await AuthStorage.getUserId();
      if (userId == null) {
        // Try to get user info from token or use a default
        // For now, we'll use a placeholder
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User ID not found, please log in again')),
        );
        return;
      }

      if (widget.account == null) {
        // Create new account
        await _accountService.createAccount(
          name: _nameController.text,
          groupId: _selectedGroupId!,
          currency: _selectedCurrency,
          startingBalance: _balanceController.text,
          isArchived: _isArchived,
          ownerUserId: userId,
        );
      } else {
        // Update existing account
        await _accountService.updateAccount(
          accountId: widget.account!.id,
          name: _nameController.text,
          currency: _selectedCurrency,
          isArchived: _isArchived,
        );
      }

      if (mounted) {
        // Notify all pages that accounts have changed
        _refreshNotifier.refreshAccounts();
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.account != null;
    final title = isEditing ? 'Edit Account' : 'Add Account';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Account'),
                    content: const Text('Are you sure you want to delete this account?'),
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    titleTextStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                    contentTextStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  setState(() {
                    _isLoading = true;
                  });

                  try {
                    await _accountService.deleteAccount(widget.account!.id);
                    if (mounted) {
                      // Notify all pages that accounts have changed
                      _refreshNotifier.refreshAccounts();
                      Navigator.of(context).pop(true); // Return true to indicate success
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  }
                }
              },
            ),
        ],
      ),
      body: _isLoadingGroups
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Account Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an account name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (!isEditing) ...[
                      DropdownButtonFormField<String>(
                        value: _selectedGroupId,
                        decoration: const InputDecoration(
                          labelText: 'Account Group',
                          border: OutlineInputBorder(),
                        ),
                        items: _accountGroups.map((group) {
                          return DropdownMenuItem(
                            value: group.id,
                            child: Text(group.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedGroupId = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select an account group';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _balanceController,
                      decoration: const InputDecoration(
                        labelText: 'Starting Balance',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a balance';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCurrency,
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'IDR', child: Text('IDR')),
                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                        DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                        DropdownMenuItem(value: 'SGD', child: Text('SGD')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCurrency = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Archived'),
                      value: _isArchived,
                      onChanged: (value) {
                        setState(() {
                          _isArchived = value!;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveAccount,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isEditing ? 'Update' : 'Create'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}