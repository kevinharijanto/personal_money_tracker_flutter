import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../storage/auth_storage.dart';
import 'login_page.dart';
import '../widgets/accounts_view.dart';
import 'transaction_detail_page.dart';
import 'account_form_page.dart';
import '../state/accounts_state.dart';

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
  @override
  void initState() {
    super.initState();
    // Trigger initial accounts load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accountsState = context.read<AccountsState>();
      accountsState.load(); // initial load (cached or fresh)
    });
  }

  @override
  void dispose() {
    super.dispose();
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
      // when transactions slice is refactored, we'll hook into it.
      // For now, AccountsState.refresh is NOT strictly necessary here.
      if (!mounted) return;
      final accountsState = context.read<AccountsState>();
      await accountsState.refresh();
    }
  }

  /// Open add account page
  Future<void> _openAddAccount() async {
    final changed = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AccountFormPage(),
      ),
    );

    if (changed == true && mounted) {
      final accountsState = context.read<AccountsState>();
      await accountsState.refresh();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AccountsView(
        isEditMode: widget.isEditMode,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewTransaction,
        child: const Icon(Icons.add),
      ),
    );
  }
}