import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../models/account_group.dart';
import '../services/transaction_service.dart';
import '../services/category_service.dart';
import '../services/account_group_service.dart';
import '../utils/money_formatter.dart';
import '../state/accounts_state.dart';
import '../state/transactions_state.dart';
import '../state/household_state.dart';

class TransactionDetailPage extends StatefulWidget {
  final String? transactionId;

  /// "INCOME" | "EXPENSE" | "TRANSFER"
  final String? initialType;

  final String? initialAccountId;
  final String? initialAccountName;

  final String? initialCategoryId;
  final String? initialCategoryName;

  const TransactionDetailPage({
    super.key,
    this.transactionId,
    this.initialType,
    this.initialAccountId,
    this.initialAccountName,
    this.initialCategoryId,
    this.initialCategoryName,
  });

  bool get isExisting => transactionId != null;

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  final CategoryService _categoryService = CategoryService();
  final AccountGroupService _accountService = AccountGroupService();
  final TransactionService _txService = TransactionService();

  TransactionModel? _tx;

  bool _isLoading = true; // loading transaction
  bool _isMetaLoading = true; // loading categories + accounts
  bool _isSaving = false;

  String _type = 'EXPENSE';
  DateTime _date = DateTime.now(); // Use current date in local timezone

  // Single-account (Income / Expense)
  String? _accountId;
  String? _accountName;

  // Transfer accounts
  String? _fromAccountId;
  String? _fromAccountName;
  String? _toAccountId;
  String? _toAccountName;

  // Category (Income / Expense, and optionally transfer fees later)
  String? _categoryId;
  String? _categoryName;

  String _currency = 'Rp';
  final Map<String, List<AccountGroup>> _householdAccountGroups = {};
  String? _accountHouseholdId;
  String? _fromAccountHouseholdId;
  String? _toAccountHouseholdId;

  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  // Meta
  List<CategoryModel> _incomeCategories = [];
  List<CategoryModel> _expenseCategories = [];
  List<CategoryModel> _activeCategories = [];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? 'EXPENSE';

    _amountFocusNode.addListener(() {
      // When gaining focus: show plain numeric value (easy to edit)
      if (_amountFocusNode.hasFocus) {
        if (_amountCtrl.text.isNotEmpty) {
          final value = MoneyFormatter.parse(_amountCtrl.text);
          if (value > 0) {
            // remove thousand separators; just a plain fixed number
            _amountCtrl.text = value.toStringAsFixed(2);
            _amountCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: _amountCtrl.text.length),
            );
          }
        }
      } else {
        // When losing focus: pretty number with thousand separators (but no Rp)
        if (_amountCtrl.text.isNotEmpty) {
          final value = MoneyFormatter.parse(_amountCtrl.text);
          if (value > 0) {
            // THIS is the key change: use formatNumber, not formatIDR
            _amountCtrl.text = MoneyFormatter.formatNumber(
              value,
            ); // e.g. 10,000.00
            _amountCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: _amountCtrl.text.length),
            );
          }
        }
      }
    });

    _init();
  }

  Future<void> _init() async {
    final householdState = context.read<HouseholdState>();
    if (!householdState.hasData && !householdState.isLoading) {
      await householdState.load();
    }

    // 1. Load existing tx if editing
    if (widget.isExisting) {
      await _loadExistingTransaction();
    } else {
      _accountId = widget.initialAccountId;
      _accountName = widget.initialAccountName;
      _categoryId = widget.initialCategoryId;
      _categoryName = widget.initialCategoryName;

      final selectedHouseholdId = context
          .read<HouseholdState>()
          .selectedHouseholdId;
      _accountHouseholdId = selectedHouseholdId;
      _fromAccountHouseholdId = selectedHouseholdId;
      _toAccountHouseholdId = selectedHouseholdId;

      if (_accountId == null) {
        _accountName = null; // this will make the UI show "Select account"
      }

      if (_type == 'TRANSFER' && _accountId != null) {
        _fromAccountId = _accountId;
        _fromAccountName = _accountName;
      }

      _isLoading = false;
    }

    // 2. Load meta once
    await _loadMetaOnce();

    if (mounted) setState(() {});
  }

  Future<void> _loadExistingTransaction() async {
    try {
      final tx = await _txService.fetchTransactionById(widget.transactionId!);
      _tx = tx;
      _type = tx.type;
      // Convert UTC date to local date without time component to avoid timezone issues
      _date = DateTime(tx.date.year, tx.date.month, tx.date.day);
      // Display amount as positive without Rp prefix (the prefix is shown in the UI)
      // Backend handles the sign based on transaction type
      _amountCtrl.text = MoneyFormatter.formatNumber(tx.amount.abs());
      _descCtrl.text = tx.description;
      _currency = tx.accountCurrency;
      _accountId = tx.accountId;
      _accountName = tx.accountName;
      _categoryId = tx.categoryId;
      _categoryName = tx.categoryName;
      final currentHouseholdId = context
          .read<HouseholdState>()
          .selectedHouseholdId;
      _accountHouseholdId = currentHouseholdId;
      _fromAccountHouseholdId = currentHouseholdId;
      _toAccountHouseholdId = currentHouseholdId;
    } catch (e) {
      // Error loading transaction
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _loadMetaOnce() async {
    _isMetaLoading = true;
    if (mounted) setState(() {});

    try {
      final householdState = context.read<HouseholdState>();
      final households = householdState.households;

      final accountGroupFutures = households.map((household) async {
        final groups = await _accountService.fetchAccountGroupsForHousehold(
          household.id,
        );
        return MapEntry(
          household.id,
          groups.where((group) => group.accounts.isNotEmpty).toList(),
        );
      }).toList();

      final results = await Future.wait([
        ...accountGroupFutures,
        _categoryService.fetchCategories('INCOME', useCache: true),
        _categoryService.fetchCategories('EXPENSE', useCache: true),
      ]);

      _householdAccountGroups.clear();
      for (var i = 0; i < accountGroupFutures.length; i++) {
        final entry = results[i] as MapEntry<String, List<AccountGroup>>;
        if (entry.value.isNotEmpty) {
          _householdAccountGroups[entry.key] = entry.value;
        }
      }

      final incomeIndex = accountGroupFutures.length;
      _incomeCategories = results[incomeIndex] as List<CategoryModel>;
      _expenseCategories = results[incomeIndex + 1] as List<CategoryModel>;

      _activeCategories = _type == 'INCOME'
          ? _incomeCategories
          : _expenseCategories;
    } catch (e) {
      // Error loading meta
    } finally {
      _isMetaLoading = false;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  String get _titleText {
    switch (_type) {
      case 'INCOME':
        return 'Income';
      case 'TRANSFER':
        return 'Transfer';
      default:
        return 'Expense';
    }
  }

  // ----------------- TYPE TABS -----------------

  void _setType(String t) {
    if (_type == t) return;
    setState(() {
      _type = t;
      // Don't reset category when switching to transfer (optional)
      if (t != 'TRANSFER') {
        _categoryId = null;
        _categoryName = null;
      }

      if (!_isMetaLoading) {
        if (_type == 'INCOME') {
          _activeCategories = _incomeCategories;
        } else if (_type == 'EXPENSE') {
          _activeCategories = _expenseCategories;
        } else {
          _activeCategories =
              _expenseCategories; // Use expense categories for transfers
        }
      }

      if (_type == 'TRANSFER' && _accountId != null) {
        _fromAccountId = _accountId;
        _fromAccountName = _accountName;
      }
    });
  }

  Widget _buildTypeTabs() {
    final types = ['INCOME', 'EXPENSE', 'TRANSFER'];
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    String label(String t) {
      switch (t) {
        case 'INCOME':
          return 'Income';
        case 'TRANSFER':
          return 'Transfer';
        default:
          return 'Expense';
      }
    }

    Color typeColor(String t) {
      switch (t) {
        case 'INCOME':
          return theme.colorScheme.tertiary;
        case 'TRANSFER':
          return theme.colorScheme.primary;
        default:
          return theme.colorScheme.error;
      }
    }

    return Row(
      children: types.map((t) {
        final selected = _type == t;
        final baseColor = typeColor(t);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: selected
                    ? baseColor.withOpacity(0.12)
                    : Colors.transparent,
                side: BorderSide(
                  color: selected ? baseColor : Colors.grey.shade400,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () => _setType(t),
              child: Text(
                label(t),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: selected ? baseColor : onSurface.withOpacity(0.7),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ----------------- SHEETS -----------------

  Future<void> _openDateSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final theme = Theme.of(context);
        DateTime temp = _date;

        return SafeArea(
          child: SizedBox(
            height: 420,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Date',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            // Use current date in local timezone
                            final now = DateTime.now();
                            _date = DateTime(now.year, now.month, now.day);
                          });
                          Navigator.of(ctx).pop();
                        },
                        child: Text('Today', style: theme.textTheme.bodyMedium),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CalendarDatePicker(
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    onDateChanged: (d) {
                      temp = d;
                      setState(() {
                        // Create a DateTime with the local timezone (no time component)
                        _date = DateTime(d.year, d.month, d.day);
                      });
                      // Close the date picker after selection
                      Navigator.of(ctx).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCategorySheet() async {
    // Allow category selection for transfers (optional)

    await showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent, // No shadow background
      builder: (ctx) {
        final theme = Theme.of(context);
        final highlightColor = _type == 'INCOME'
            ? theme.colorScheme.tertiary
            : (_type == 'TRANSFER'
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error);
        return Container(
          height:
              MediaQuery.of(context).size.height * 0.5, // Keyboard-style height
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Text(
                      'Select Category',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Add category',
                      icon: const Icon(Icons.add),
                      onPressed: () => _addCategoryForCurrentType(ctx),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Category grid
              Expanded(
                child: _isMetaLoading
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.count(
                        crossAxisCount: 3,
                        padding: const EdgeInsets.all(12),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.6,
                        children: _activeCategories
                            .map(
                              (c) => OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: c.id == _categoryId
                                        ? highlightColor
                                        : Colors.grey.shade500,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _categoryId = c.id;
                                    _categoryName = c.name;
                                  });
                                  Navigator.of(ctx).pop();
                                },
                                child: Text(
                                  c.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAccountSheet({String? target}) async {
    String title;
    if (target == 'from') {
      title = 'From account';
    } else if (target == 'to') {
      title = 'To account';
    } else {
      title = 'Account';
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent, // No shadow background
      builder: (ctx) {
        final theme = Theme.of(context);
        return Container(
          height:
              MediaQuery.of(context).size.height * 0.7, // Keyboard-style height
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Account groups list
              Expanded(
                child: _isMetaLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildHouseholdAccountList(
                        sheetContext: ctx,
                        theme: theme,
                        target: target,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHouseholdAccountList({
    required BuildContext sheetContext,
    required ThemeData theme,
    String? target,
  }) {
    final householdState = context.read<HouseholdState>();
    final households = householdState.households
        .where((h) => (_householdAccountGroups[h.id]?.isNotEmpty ?? false))
        .toList();

    if (households.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No accounts found in your households.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      children: households.map((household) {
        final groups = _householdAccountGroups[household.id] ?? [];
        return ExpansionTile(
          key: ValueKey('household_${household.id}'),
          title: Text(
            household.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          children: groups.map((group) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Text(
                    group.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
                ...group.accounts.map((acc) {
                  final isSelected = target == 'from'
                      ? acc.id == _fromAccountId
                      : target == 'to'
                      ? acc.id == _toAccountId
                      : acc.id == _accountId;

                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.account_circle, size: 20),
                    title: Text(acc.name, style: theme.textTheme.bodyMedium),
                    trailing: isSelected
                        ? Icon(Icons.check, color: theme.colorScheme.tertiary)
                        : null,
                    onTap: () => _selectAccountFromHousehold(
                      account: acc,
                      householdId: household.id,
                      householdName: household.name,
                      target: target,
                      sheetContext: sheetContext,
                    ),
                  );
                }),
                const Divider(height: 0),
              ],
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  void _selectAccountFromHousehold({
    required AccountModel account,
    required String householdId,
    required String householdName,
    required BuildContext sheetContext,
    String? target,
  }) {
    if (target == 'to' && account.id == _fromAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Source and destination cannot be the same account.'),
        ),
      );
      return;
    }
    if (target == 'from' && account.id == _toAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Source and destination cannot be the same account.'),
        ),
      );
      return;
    }

    setState(() {
      if (target == 'from') {
        _fromAccountId = account.id;
        _fromAccountName = '${account.name} ($householdName)';
        _fromAccountHouseholdId = householdId;
      } else if (target == 'to') {
        _toAccountId = account.id;
        _toAccountName = '${account.name} ($householdName)';
        _toAccountHouseholdId = householdId;
      } else {
        _accountId = account.id;
        _accountName = '${account.name} ($householdName)';
        _accountHouseholdId = householdId;
        _currency = account.currency;
      }
    });

    Navigator.of(sheetContext).pop();
  }

  Future<void> _addCategoryForCurrentType(BuildContext sheetContext) async {
    final type = _type; // 'INCOME' or 'EXPENSE'
    if (type == 'TRANSFER') return;

    final controller = TextEditingController();

    final newName = await showDialog<String?>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(
            'New category',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Category name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogCtx).pop(controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (newName == null || newName.isEmpty) return;

    try {
      final created = await _categoryService.createCategory(
        name: newName,
        type: type,
      );

      setState(() {
        if (type == 'INCOME') {
          _incomeCategories.add(created);
          _activeCategories = _incomeCategories;
        } else if (type == 'EXPENSE') {
          _expenseCategories.add(created);
          _activeCategories = _expenseCategories;
        }
        _categoryId = created.id;
        _categoryName = created.name;
      });
    } catch (e) {}
  }

  // ----------------- SAVE -----------------

  Future<void> _onSavePressed() async {
    if (_isSaving) return;

    final rawAmount = _amountCtrl.text.trim();
    if (rawAmount.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an amount')));
      return;
    }

    // Parse the formatted amount string back to double
    final amountDouble = MoneyFormatter.parse(rawAmount);
    if (amountDouble <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than zero')),
      );
      return;
    }

    // Transfer handling
    if (_type == 'TRANSFER') {
      if (_fromAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select the source account')),
        );
        return;
      }
      if (_toAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select the destination account'),
          ),
        );
        return;
      }
      if (_fromAccountId == _toAccountId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Source and destination cannot be the same'),
          ),
        );
        return;
      }
    } else {
      if (_accountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an account')),
        );
        return;
      }
      if (_accountHouseholdId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to determine household for the selected account',
            ),
          ),
        );
        return;
      }
      if (_categoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category')),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Convert local date to UTC at noon to avoid timezone issues
      final dateUtc = DateTime(
        _date.year,
        _date.month,
        _date.day,
        12,
        0,
        0,
      ).toUtc();

      final transactionsState = context.read<TransactionsState>();

      if (_type == 'TRANSFER') {
        // Create transfer
        await transactionsState.createTransfer(
          fromAccountId: _fromAccountId!,
          toAccountId: _toAccountId!,
          amount: amountDouble.toString(),
          date: dateUtc,
          description: _descCtrl.text.trim(),
          householdId: _fromAccountHouseholdId,
        );
      } else if (widget.isExisting) {
        // Update existing transaction
        await transactionsState.updateTransaction(
          transactionId: widget.transactionId!,
          type: _type, // 'INCOME' or 'EXPENSE'
          accountId: _accountId!,
          categoryId: _categoryId!,
          amount: amountDouble.toString(),
          date: dateUtc,
          description: _descCtrl.text.trim(),
          householdId: _accountHouseholdId,
        );
      } else {
        // Create new transaction
        await transactionsState.createTransaction(
          type: _type, // 'INCOME' or 'EXPENSE'
          accountId: _accountId!,
          categoryId: _categoryId!,
          amount: amountDouble.toString(),
          date: dateUtc,
          description: _descCtrl.text.trim(),
          householdId: _accountHouseholdId,
        );
      }

      if (mounted) {
        // Use addPostFrameCallback to ensure state changes happen after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Refresh accounts state to update account balances
          if (mounted) {
            final accountsState = context.read<AccountsState>();
            accountsState.refresh();
          }
        });

        Navigator.of(context).pop(true); // tell caller to refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save transaction: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ----------------- DELETE -----------------

  Future<void> _onDeletePressed() async {
    if (widget.transactionId == null) {
      return;
    }

    // Check if this is a transfer transaction
    final isTransfer = _tx?.transferGroupId != null;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            isTransfer ? 'Delete Transfer' : 'Delete Transaction',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          content: Text(
            isTransfer
                ? 'Are you sure you want to delete this transfer? Both the source and destination transactions will be deleted. This action cannot be undone.'
                : 'Are you sure you want to delete this transaction? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final transactionsState = context.read<TransactionsState>();

      if (isTransfer && _tx?.transferGroupId != null) {
        // Delete the entire transfer (both transactions)
        await transactionsState.deleteTransfer(_tx!.transferGroupId!);
      } else {
        // Delete single transaction
        await transactionsState.deleteTransaction(widget.transactionId!);
      }

      if (mounted) {
        // Use addPostFrameCallback to ensure state changes happen after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Refresh accounts state to update account balances
          if (mounted) {
            final accountsState = context.read<AccountsState>();
            accountsState.refresh();
          }
        });

        Navigator.of(context).pop(true); // tell caller to refresh
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ----------------- UI HELPERS -----------------

  String _formatDate(DateTime d) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = weekdays[d.weekday - 1];
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$weekday, $mm/$dd/${d.year}';
  }

  String _formatCurrencyFromString(String amountStr) {
    // Parse the string to double and format it
    try {
      final amount =
          double.tryParse(amountStr.replaceAll(',', '').replaceAll(' ', '')) ??
          0.0;
      return MoneyFormatter.formatNumber(amount);
    } catch (e) {
      return amountStr;
    }
  }

  Widget _buildLabelRow({
    required String label,
    required String value,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow({Widget? trailing}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              'Amount',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _amountCtrl,
              focusNode: _amountFocusNode,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText: '0',
                prefixText: 'Rp ', // 👈 visual Rp only
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              inputFormatters: [
                // Only digits, comma, dot
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  Widget _buildDescriptionBox() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.dividerColor),
      ),
      child: TextFormField(
        controller: _descCtrl,
        maxLines: 4,
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildSaveButtonRow() {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 4),
        child: widget.isExisting
            ? Row(
                children: [
                  // Delete button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _onDeletePressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSaving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.onError,
                                ),
                              ),
                            )
                          : const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Save/Update button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _onSavePressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSaving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          : Text(
                              'Update',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              )
            : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _onSavePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : Text(
                          'Save',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
      ),
    );
  }

  // ----------------- INLINE SELECTORS -----------------

  Widget _buildInlineAccountSelector({String? target}) {
    String label;
    String? value;

    if (target == 'from') {
      label = 'From';
      value = _fromAccountName;
    } else if (target == 'to') {
      label = 'To';
      value = _toAccountName;
    } else {
      label = 'Account';
      value = _accountName;
    }

    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _openAccountSheet(target: target),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value ?? 'Select account',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: value != null
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineCategorySelector() {
    final theme = Theme.of(context);
    return InkWell(
      onTap: _openCategorySheet,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                'Category',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _categoryName ?? 'Select category',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _categoryName != null
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------- BODY -----------------

  Widget _buildIncomeExpenseBody() {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTypeTabs(),
        const SizedBox(height: 16),
        _buildLabelRow(
          label: 'Date',
          value: _formatDate(_date),
          onTap: _openDateSheet,
        ),
        const Divider(height: 1),
        _buildInlineAccountSelector(),
        const SizedBox(height: 16),
        _buildInlineCategorySelector(),
        const SizedBox(height: 16),
        _buildAmountRow(),
        const Divider(height: 1),
        const SizedBox(height: 24),
        Text(
          'Description',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 8),
        _buildDescriptionBox(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTransferBody() {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTypeTabs(),
        const SizedBox(height: 16),
        _buildLabelRow(
          label: 'Date',
          value: _formatDate(_date),
          onTap: _openDateSheet,
        ),
        const Divider(height: 1),
        _buildInlineAccountSelector(target: 'from'),
        const SizedBox(height: 16),
        _buildInlineAccountSelector(target: 'to'),
        const SizedBox(height: 16),
        _buildAmountRow(),
        const Divider(height: 1),
        const SizedBox(height: 24),
        Text(
          'Description',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 8),
        _buildDescriptionBox(),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _type == 'TRANSFER'
        ? _buildTransferBody()
        : _buildIncomeExpenseBody();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          _titleText,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: body),
                _buildSaveButtonRow(),
              ],
            ),
    );
  }
}
