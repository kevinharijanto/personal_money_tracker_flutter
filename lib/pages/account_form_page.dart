import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account_group.dart';
import '../services/account_group_service.dart';
import '../state/accounts_state.dart';

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
  final AccountGroupService _accountGroupService = AccountGroupService();
  
  String? _selectedGroupId;
  String _selectedCurrency = 'IDR';
  String _selectedScope = 'PERSONAL';
  bool _isArchived = false;
  bool _includeInTotals = true;
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
      _selectedScope = widget.account!.scope;
      _isArchived = widget.account!.isArchived;
      _includeInTotals = widget.account!.includeInTotals;
      _selectedGroupId = widget.groupId; // This would need to be passed when editing
    } else if (widget.groupId != null) {
      _selectedGroupId = widget.groupId;
      _balanceController.text = '0';
    } else {
      _balanceController.text = '0';
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

    final accountsState = context.read<AccountsState>();
    final isEditing = widget.account != null;

    try {
      if (!isEditing) {
        // Create new account
        await accountsState.createAccount(
          name: _nameController.text,
          groupId: _selectedGroupId!,
          currency: _selectedCurrency,
          startingBalance:
              _balanceController.text.isEmpty ? '0' : _balanceController.text,
          isArchived: _isArchived,
          scope: _selectedScope,
          includeInTotals: _includeInTotals,
        );
      } else {
        // Update existing account
        await accountsState.updateAccount(
          accountId: widget.account!.id,
          name: _nameController.text,
          currency: _selectedCurrency,
          isArchived: _isArchived,
          scope: _selectedScope,
          startingBalance:
              _balanceController.text.isEmpty ? '0' : _balanceController.text,
          includeInTotals: _includeInTotals,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true); // signal success to caller
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
        title: Text(title, style: Theme.of(context).textTheme.headlineLarge),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Delete Account', style: Theme.of(context).textTheme.headlineLarge),
                    content: Text('Are you sure you want to delete this account?', style: Theme.of(context).textTheme.titleLarge),
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    titleTextStyle: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    contentTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    final accountsState = context.read<AccountsState>();
                    await accountsState.deleteAccount(widget.account!.id);
                    if (mounted) {
                      Navigator.of(context).pop(true);
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
                            child: Text(group.name, style: Theme.of(context).textTheme.bodyMedium),
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
                      items: [
                        DropdownMenuItem(value: 'IDR', child: Text('IDR', style: Theme.of(context).textTheme.bodyMedium)),
                        DropdownMenuItem(value: 'USD', child: Text('USD', style: Theme.of(context).textTheme.bodyMedium)),
                        DropdownMenuItem(value: 'EUR', child: Text('EUR', style: Theme.of(context).textTheme.bodyMedium)),
                        DropdownMenuItem(value: 'SGD', child: Text('SGD', style: Theme.of(context).textTheme.bodyMedium)),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCurrency = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedScope,
                      decoration: const InputDecoration(
                        labelText: 'Scope',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(value: 'PERSONAL', child: Text('Personal', style: Theme.of(context).textTheme.bodyMedium)),
                        DropdownMenuItem(value: 'HOUSEHOLD', child: Text('Household', style: Theme.of(context).textTheme.bodyMedium)),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedScope = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      title: Text('Add to totals', style: Theme.of(context).textTheme.bodyMedium),
                      subtitle: Text(
                        'Disable to exclude this account from the Assets bar and group totals.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      activeColor: Theme.of(context).colorScheme.primary,
                      value: _includeInTotals,
                      onChanged: (value) {
                        setState(() {
                          _includeInTotals = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: Text('Archived', style: Theme.of(context).textTheme.bodyMedium),
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
