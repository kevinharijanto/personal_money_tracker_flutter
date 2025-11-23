import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/accounts_view.dart';
import '../pages/account_form_page.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accountsState = context.read<AccountsState>();
      accountsState.load();
    });
  }

  Future<void> _openAddAccount() async {
    final changed = await Navigator.of(context).push<bool>(
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
    );
  }
}
