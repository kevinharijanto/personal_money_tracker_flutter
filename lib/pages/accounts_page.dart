import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/accounts_view.dart';
import '../state/accounts_state.dart';
import '../state/transactions_state.dart';
import '../state/household_state.dart';

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
  bool _isSwitchingHousehold = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final householdState = context.read<HouseholdState>();
      if (!householdState.hasData && !householdState.isLoading) {
        await householdState.load();
        if (!mounted) return;
      }
      final accountsState = context.read<AccountsState>();
      await accountsState.load();
    });
  }

  Future<void> _handleHouseholdChanged(String householdId) async {
    if (_isSwitchingHousehold) return;
    setState(() {
      _isSwitchingHousehold = true;
    });

    try {
      final householdState = context.read<HouseholdState>();
      final accountsState = context.read<AccountsState>();
      final transactionsState = context.read<TransactionsState>();

      await householdState.selectHousehold(householdId);
      await Future.wait([accountsState.refresh(), transactionsState.refresh()]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to switch household: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingHousehold = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 8),
          _HouseholdSelector(
            isSwitching: _isSwitchingHousehold,
            onSelect: _handleHouseholdChanged,
          ),
          Expanded(child: AccountsView(isEditMode: widget.isEditMode)),
        ],
      ),
    );
  }
}

class _HouseholdSelector extends StatelessWidget {
  final bool isSwitching;
  final ValueChanged<String> onSelect;

  const _HouseholdSelector({required this.isSwitching, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Consumer<HouseholdState>(
      builder: (context, householdState, child) {
        final households = householdState.households;
        final selectedId = householdState.selectedHouseholdId;

        if (householdState.isLoading && households.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(),
          );
        }

        if (households.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              householdState.error ??
                  'No households found. Create one or accept an invitation.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Household',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (isSwitching) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedId,
                isDense: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: households
                  .map(
                    (h) {
                      final isCurrent = h.id == selectedId;
                      final label = isCurrent
                          ? '${h.name} (Mine)'
                          : '${h.name} (Others)';

                      return DropdownMenuItem<String>(
                        value: h.id,
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  )
                  .toList(),
                onChanged: isSwitching
                    ? null
                    : (value) {
                        if (value != null &&
                            value != householdState.selectedHouseholdId) {
                          onSelect(value);
                        }
                      },
              ),
            ],
          ),
        );
      },
    );
  }
}
