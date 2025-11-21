// lib/pages/accounts_page.dart
import 'package:flutter/material.dart';
import '../storage/auth_storage.dart';
import 'login_page.dart';
import '../widgets/accounts_view.dart';
import 'transaction_detail_page.dart';
import 'account_form_page.dart';
import '../utils/refresh_notifier.dart';

class AccountsPage extends StatefulWidget {
  final bool isEditMode;
  final VoidCallback? onToggleEditMode;

  const AccountsPage({
    super.key,
    this.isEditMode = false,
    this.onToggleEditMode,
  });

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  int _refreshToken = 0;
  final RefreshNotifier _refreshNotifier = RefreshNotifier.instance;

  @override
  void initState() {
    super.initState();
    _refreshNotifier.addListener(_onRefreshNotifierChanged);
  }

  @override
  void dispose() {
    _refreshNotifier.removeListener(_onRefreshNotifierChanged);
    super.dispose();
  }

  void _onRefreshNotifierChanged() {
    if (mounted) {
      _handleAccountsDataChanged();
    }
  }

  /// Called when *any* child page (AccountsView / AccountTransactionsPage)
  /// reports that data has changed (e.g. a transaction was added/edited).
  void _handleAccountsDataChanged() {
    setState(() {
      _refreshToken++; // triggers AccountsView to refetch account groups
    });
  }

  /// FAB → open add-transaction page from the main Accounts screen
  Future<void> _openNewTransaction() async {
    final changed = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TransactionDetailPage(
          initialType: 'EXPENSE', // default tab when creating
        ),
      ),
    );

    // If the detail page popped with `Navigator.pop(true)` → refresh accounts
    if (changed == true) {
      _handleAccountsDataChanged();
      // Notify other pages that transactions have changed
      _refreshNotifier.refreshTransactions();
    }
  }

  /// Open add account page
  Future<void> _openAddAccount() async {
    final changed = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AccountFormPage(),
      ),
    );

    // If the form page popped with `Navigator.pop(true)` → refresh accounts
    if (changed == true) {
      _handleAccountsDataChanged();
      // Notify other pages that accounts have changed
      _refreshNotifier.refreshAccounts();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AccountsView(
        refreshToken: _refreshToken,
        onDataChanged: _handleAccountsDataChanged, // 🔥 important
        isEditMode: widget.isEditMode,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewTransaction,
        child: const Icon(Icons.add),
      ),
    );
  }
}