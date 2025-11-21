import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'storage/auth_storage.dart';
import 'pages/login_page.dart';
import 'pages/accounts_page.dart';
import 'pages/account_transactions_page.dart';
import 'pages/settings_page.dart';
import 'pages/account_form_page.dart';
import 'widgets/bottom_navigation_bar.dart' as custom;
import 'ui/slide_transition_builder.dart'; // adjust the path
import 'providers/theme_provider.dart';
import 'services/api_client.dart';
import 'state/accounts_state.dart';
import 'state/transactions_state.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AccountsState()),
        ChangeNotifierProvider(create: (_) => TransactionsState()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'ApliGaji',
            theme: themeProvider.themeData,
            navigatorKey: ApiClient.navigatorKey,
            home: const RootPage(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

/// This page checks if a token exists and then routes to:
/// - HomePage if logged in
/// - LoginPage if not logged in
class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => RootPageState();
}

class RootPageState extends State<RootPage> {
  int _currentIndex = 0; // Start with Accounts page
  bool _isEditMode = false; // Edit mode for accounts page
  bool _isAuthenticated = false;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
  }

  Future<void> _checkAuthenticationStatus() async {
    final token = await AuthStorage.getToken();
    setState(() {
      _isAuthenticated = token != null && token.isNotEmpty;
      _isCheckingAuth = false;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _logout() async {
    await AuthStorage.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
  }

  Future<void> _openAddAccount() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AccountFormPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking authentication
    if (_isCheckingAuth) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show login page if not authenticated
    if (!_isAuthenticated) {
      return const LoginPage();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        actions: _currentIndex == 1 ? [
          IconButton(
            onPressed: _toggleEditMode,
            icon: Icon(_isEditMode ? Icons.check : Icons.edit),
            tooltip: _isEditMode ? 'Done Editing' : 'Edit Accounts',
          ),
          IconButton(
            onPressed: _openAddAccount,
            icon: const Icon(Icons.add),
            tooltip: 'Add Account',
          ),
        ] : null,
      ),
      body: _buildCurrentPage(),
      bottomNavigationBar: custom.BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return AccountTransactionsPage(
          key: ValueKey('transactions_page_$_isAuthenticated'), // Change key when auth state changes
          accountId: '', // Empty string to indicate all accounts
          accountName: 'All Accounts',
          currency: 'IDR',
          currentBalance: 0.0, // We don't have a total balance for all accounts
          showAppBar: false, // Hide AppBar since it's shown in the root page
        );
      case 1:
        return AccountsPage(
          key: ValueKey('accounts_page_$_isAuthenticated'), // Change key when auth state changes
          isEditMode: _isEditMode,
          onToggleEditMode: _toggleEditMode,
        );
      case 2:
        return const SettingsPage(
          key: ValueKey('settings_page'),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Transactions';
      case 1:
        return 'Accounts';
      case 2:
        return 'Settings';
      default:
        return 'Money Tracker';
    }
  }
}
