import 'package:flutter/foundation.dart';

import '../models/account_group.dart';
import '../services/account_group_service.dart';
import '../services/account_service.dart';
import '../storage/auth_storage.dart';

class AccountsState extends ChangeNotifier {
  final AccountGroupService _groupService;
  final AccountService _accountService;

  AccountsState({
    AccountGroupService? groupService,
    AccountService? accountService,
  })  : _groupService = groupService ?? AccountGroupService(),
        _accountService = accountService ?? AccountService();

  bool _isLoading = false;
  String? _error;
  List<AccountGroup> _groups = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<AccountGroup> get groups => _groups;

  bool get hasData => _groups.isNotEmpty;

  /// Initial load (or reuse existing data when not forced).
  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (!force && _groups.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result =
          await _groupService.fetchAccountGroups(useCache: !force);
      _groups = result;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Force reload from backend (no cache).
  Future<void> refresh() => load(force: true);

  /// Reorder accounts within a group and persist to backend.
  Future<void> reorderAccounts(
    String groupId,
    int oldIndex,
    int newIndex,
  ) async {
    final groupIndex = _groups.indexWhere((g) => g.id == groupId);
    if (groupIndex == -1) return;

    final group = _groups[groupIndex];
    final accounts = List<AccountModel>.from(group.accounts);

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final moved = accounts.removeAt(oldIndex);
    accounts.insert(newIndex, moved);

    // Optimistic update in memory
    _groups[groupIndex] = AccountGroup(
      id: group.id,
      name: group.name,
      kind: group.kind,
      accounts: accounts,
    );
    notifyListeners();

    try {
      await _accountService.reorderAccounts(
        accountIds: accounts.map((a) => a.id).toList(),
      );
    } catch (e) {
      // You can choose to roll back or just store error
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Create a new account and refresh data.
  Future<void> createAccount({
    required String name,
    required String groupId,
    required String currency,
    required String startingBalance,
    bool isArchived = false,
  }) async {
    final userId = await AuthStorage.getUserId();
    if (userId == null) {
      throw Exception('User ID not found. Please log in again.');
    }

    await _accountService.createAccount(
      name: name,
      groupId: groupId,
      currency: currency,
      startingBalance: startingBalance,
      isArchived: isArchived,
      ownerUserId: userId,
    );

    await refresh();
  }

  /// Update an existing account and refresh.
  Future<void> updateAccount({
    required String accountId,
    required String name,
    required String currency,
    required bool isArchived,
  }) async {
    await _accountService.updateAccount(
      accountId: accountId,
      name: name,
      currency: currency,
      isArchived: isArchived,
    );

    await refresh();
  }

  /// Delete an account and refresh.
  Future<void> deleteAccount(String accountId) async {
    await _accountService.deleteAccount(accountId);
    await refresh();
  }
}
