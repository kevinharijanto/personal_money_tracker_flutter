// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import '../storage/auth_storage.dart';
import 'login_page.dart';
import '../widgets/accounts_view.dart';
import 'transaction_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _refreshToken = 0;
  String? _name;
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final name = await AuthStorage.getUserName();
    final email = await AuthStorage.getUserEmail();
    if (!mounted) return;
    setState(() {
      _name = name;
      _email = email;
    });
  }

  Future<void> _logout() async {
    await AuthStorage.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _name ?? 'User';
    final email = _email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewTransaction,
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $name',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AccountsView(
              refreshToken: _refreshToken,
              onDataChanged: _handleAccountsDataChanged, // 🔥 important
            ),
          ),
        ],
      ),
    );
  }
}
