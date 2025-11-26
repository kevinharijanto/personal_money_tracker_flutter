import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../storage/auth_storage.dart';
import '../providers/theme_provider.dart';
import 'category_management_page.dart';
import 'account_group_management_page.dart';
import 'login_page.dart';
import 'household_invitations_page.dart';
import '../state/accounts_state.dart';
import '../state/household_state.dart';
import '../services/auth_service.dart';
import '../models/household.dart';
import '../state/transactions_state.dart';
import '../storage/include_totals_storage.dart';

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
  final AuthService _authService = AuthService();

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

  Future<void> _showRenameHouseholdDialog(Household household) async {
    final controller = TextEditingController(text: household.name);
    try {
      final newName = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Rename Household'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Household Name'),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (newName == null) return;
      final trimmed = newName.trim();
      if (trimmed.isEmpty || trimmed == household.name) return;

      try {
        await context.read<HouseholdState>().renameHousehold(
          householdId: household.id,
          newName: trimmed,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Household name updated.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename household: $e')),
        );
      }
    } finally {
      controller.dispose();
    }
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
    context.read<AccountsState>().clear();
    context.read<TransactionsState>().clear();
    context.read<HouseholdState>().clear();

    await AuthStorage.clear();
    await IncludeTotalsStorage.clear();

    if (!mounted) return;
    
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _showSettingsPasswordDialog() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool oldPasswordObscured = true;
    bool newPasswordObscured = true;
    bool confirmPasswordObscured = true;
    final formKey = GlobalKey<FormState>(
      debugLabel: 'settings_change_password_form',
    );
    String? dialogError;
    bool dialogLoading = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }

              setDialogState(() {
                dialogLoading = true;
                dialogError = null;
              });

              try {
                final token = await AuthStorage.getToken();
                if (token == null || token.isEmpty) {
                  throw Exception('Session expired. Please log in again.');
                }

                await _authService.changePassword(
                  oldPassword: oldPasswordController.text,
                  newPassword: newPasswordController.text,
                  token: token,
                );

                if (!mounted) return;
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password updated successfully.'),
                  ),
                );
              } catch (e) {
                setDialogState(() {
                  dialogError = e.toString();
                });
              } finally {
                setDialogState(() {
                  dialogLoading = false;
                });
              }
            }

            return AlertDialog(
              title: const Text('Change Password'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: oldPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              oldPasswordObscured
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                oldPasswordObscured = !oldPasswordObscured;
                              });
                            },
                          ),
                        ),
                        obscureText: oldPasswordObscured,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Current password is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newPasswordController,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              newPasswordObscured
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                newPasswordObscured = !newPasswordObscured;
                              });
                            },
                          ),
                        ),
                        obscureText: newPasswordObscured,
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'New password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              confirmPasswordObscured
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                confirmPasswordObscured =
                                    !confirmPasswordObscured;
                              });
                            },
                          ),
                        ),
                        obscureText: confirmPasswordObscured,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm new password';
                          }
                          if (value != newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      if (dialogError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          dialogError!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: dialogLoading
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: dialogLoading ? null : submit,
                  child: dialogLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update Password'),
                ),
              ],
            );
          },
        );
      },
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
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Consumer<HouseholdState>(
                builder: (context, householdState, _) {
                  final households = householdState.households;
                  final selectedId = householdState.selectedHouseholdId; // 👈 current household

                  if (households.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Households',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Rename your current household or others you are a member of.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          ...households.map((h) {
                            final isCurrent = h.id == selectedId;
                            final subtitleText = isCurrent
                                ? 'This is your current household'
                                : 'Other household';

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                h.name,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              subtitle: Text(
                                subtitleText,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showRenameHouseholdDialog(h),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Security',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Keep your account secure by updating your password regularly.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: Icon(
                          Icons.password,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          'Change Password',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: _showSettingsPasswordDialog,
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
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select your timezone to ensure dates and times are displayed correctly.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _currentTimezone,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage your income and expense categories.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: Icon(
                          Icons.trending_up,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                        title: Text(
                          'Income Category Setting',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
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
                        leading: Icon(
                          Icons.trending_down,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(
                          'Expenses Category Setting',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
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
                        'Household Invitations',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Invite others to your household or accept invitations you have received.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: Icon(
                          Icons.group_add,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          'Manage Invitations',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HouseholdInvitationsPage(),
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
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage your account groups (Bank Accounts, Cash, Credit Cards, etc.).',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: Icon(
                          Icons.account_balance,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          'Account Groups',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () async {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AccountGroupManagementPage(),
                            ),
                          );
                          // After returning from account group management, refresh accounts page
                          if (mounted) {
                            // Use AccountsState to refresh accounts
                            final accountsState = context.read<AccountsState>();
                            await accountsState.refresh();
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
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Toggle dark mode for better viewing experience.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: Text(
                          'Dark Mode',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        subtitle: Text(
                          themeProvider.isDarkMode
                              ? 'Currently enabled'
                              : 'Currently disabled',
                        ),
                        value: themeProvider.isDarkMode,
                        onChanged: (value) {
                          _toggleDarkMode();
                        },
                        secondary: Icon(
                          themeProvider.isDarkMode
                              ? Icons.dark_mode
                              : Icons.light_mode,
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
                        'About',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Personal Money Tracker v1.0.0',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A simple app to track your income, expenses, and account balances.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
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
