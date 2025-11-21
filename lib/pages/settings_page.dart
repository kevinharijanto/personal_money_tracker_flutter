import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome;
import 'package:provider/provider.dart';
import '../storage/auth_storage.dart';
import '../providers/theme_provider.dart';
import 'category_management_page.dart';
import 'account_group_management_page.dart';
import 'accounts_page.dart';
import 'login_page.dart';
import '../utils/refresh_notifier.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _currentTimezone = 'UTC+7';
  String? _name;
  String? _email;
  bool _isDarkMode = false;

  final List<Map<String, String>> _timezones = [
    {'value': 'UTC', 'label': 'UTC (Coordinated Universal Time)'},
    {'value': 'UTC+7', 'label': 'UTC+7 (Bangkok, Hanoi, Jakarta)'},
    {'value': 'UTC+8', 'label': 'UTC+8 (Beijing, Perth, Singapore)'},
    {'value': 'UTC+9', 'label': 'UTC+9 (Tokyo, Seoul)'},
    {'value': 'UTC+10', 'label': 'UTC+10 (Sydney, Melbourne)'},
    {'value': 'UTC+11', 'label': 'UTC+11 (Solomon Islands, New Caledonia)'},
    {'value': 'UTC+12', 'label': 'UTC+12 (Auckland, Wellington)'},
    {'value': 'UTC-11', 'label': 'UTC-11 (Midway Island, Samoa)'},
    {'value': 'UTC-10', 'label': 'UTC-10 (Honolulu)'},
    {'value': 'UTC-9', 'label': 'UTC-9 (Alaska)'},
    {'value': 'UTC-8', 'label': 'UTC-8 (Pacific Time)'},
    {'value': 'UTC-7', 'label': 'UTC-7 (Mountain Time)'},
    {'value': 'UTC-6', 'label': 'UTC-6 (Central Time)'},
    {'value': 'UTC-5', 'label': 'UTC-5 (Eastern Time)'},
    {'value': 'UTC-4', 'label': 'UTC-4 (Atlantic Time)'},
    {'value': 'UTC-3', 'label': 'UTC-3 (Brazil, Buenos Aires)'},
    {'value': 'UTC-2', 'label': 'UTC-2 (Mid-Atlantic)'},
    {'value': 'UTC-1', 'label': 'UTC-1 (Azores, Cape Verde Islands)'},
    {'value': 'UTC+0', 'label': 'UTC+0 (Western European Time)'},
    {'value': 'UTC+1', 'label': 'UTC+1 (Central European Time)'},
    {'value': 'UTC+2', 'label': 'UTC+2 (Eastern European Time)'},
    {'value': 'UTC+3', 'label': 'UTC+3 (Moscow, St. Petersburg)'},
    {'value': 'UTC+4', 'label': 'UTC+4 (Abu Dhabi, Muscat)'},
    {'value': 'UTC+5', 'label': 'UTC+5 (Ekaterinburg)'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentTimezone();
    _loadUserInfo();
    _loadDarkModePreference();
  }

  Future<void> _loadCurrentTimezone() async {
    final savedTimezone = await AuthStorage.getTimezone();
    if (savedTimezone != null && savedTimezone.isNotEmpty) {
      setState(() {
        _currentTimezone = savedTimezone;
      });
    }
  }

  Future<void> _saveTimezone(String timezone) async {
    await AuthStorage.saveTimezone(timezone);
    setState(() {
      _currentTimezone = timezone;
    });
  }

  Future<void> _loadUserInfo() async {
    final name = await AuthStorage.getUserName();
    final email = await AuthStorage.getUserEmail();
    if (!mounted) return;
    setState(() {
      _name = name;
      _email = email;
    });
  }

  Future<void> _loadDarkModePreference() async {
    final isDarkMode = await AuthStorage.getDarkMode();
    if (isDarkMode != null) {
      setState(() {
        _isDarkMode = isDarkMode!;
      });
    }
  }

  Future<void> _toggleDarkMode() async {
    // Use the ThemeProvider to toggle the theme
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    await themeProvider.toggleTheme();
    
    // Update local state to match
    setState(() {
      _isDarkMode = themeProvider.isDarkMode;
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

  @override
  Widget build(BuildContext context) {
    final name = _name ?? 'User';
    final email = _email ?? '';

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        // Update local state when theme provider changes
        if (_isDarkMode != themeProvider.isDarkMode) {
          _isDarkMode = themeProvider.isDarkMode;
        }
        
        return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Timezone',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select your timezone to ensure dates and times are displayed correctly.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _currentTimezone,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    isExpanded: true,
                    items: _timezones.map((tz) {
                      return DropdownMenuItem<String>(
                        value: tz['value']!,
                        child: Text(
                          tz['label']!,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _saveTimezone(value!);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current: ${_timezones.firstWhere((tz) => tz['value'] == _currentTimezone)['label'] ?? 'Unknown'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category Management',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your income and expense categories.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.trending_up, color: Colors.green),
                    title: const Text('Income Category Setting'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CategoryManagementPage(
                            categoryType: 'INCOME',
                            title: 'Income Categories',
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.trending_down, color: Colors.red),
                    title: const Text('Expenses Category Setting'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CategoryManagementPage(
                            categoryType: 'EXPENSE',
                            title: 'Expense Categories',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Group Management',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your account groups (Bank Accounts, Cash, Credit Cards, etc.).',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.account_balance, color: Colors.blue),
                    title: const Text('Account Groups'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () async {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AccountGroupManagementPage(),
                        ),
                      );
                      // After returning from account group management, refresh accounts page
                      if (mounted) {
                        // Trigger the global refresh notifier to update the accounts page
                        RefreshNotifier.instance.refreshAccounts();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toggle dark mode for better viewing experience.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    subtitle: Text(themeProvider.isDarkMode ? 'Currently enabled' : 'Currently disabled'),
                    value: themeProvider.isDarkMode,
                    onChanged: (value) {
                      _toggleDarkMode();
                    },
                    secondary: Icon(themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Personal Money Tracker v1.0.0',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A simple app to track your income, expenses, and account balances.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
        );
      },
    );
  }
}