import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../services/household_service.dart';
import '../storage/auth_storage.dart';

class TransactionsState extends ChangeNotifier {
  final TransactionService _transactionService;
  final HouseholdService _householdService;

  TransactionsState({
    TransactionService? transactionService,
    HouseholdService? householdService,
  })  : _transactionService = transactionService ?? TransactionService(),
        _householdService = householdService ?? HouseholdService();

  bool _isLoading = false;
  String? _error;
  List<TransactionModel> _transactions = [];
  String _typeFilter = 'ALL'; // ALL, INCOME, EXPENSE

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<TransactionModel> get transactions => _transactions;
  String get typeFilter => _typeFilter;
  bool get hasData => _transactions.isNotEmpty;

  /// Get filtered transactions based on current filter
  List<TransactionModel> get filteredTransactions {
    if (_typeFilter == 'ALL') return _transactions;
    return _transactions.where((tx) => tx.type == _typeFilter).toList();
  }

  /// Initial load (or reuse existing data when not forced).
  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (!force && _transactions.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Ensure we have a householdId
      var householdId = await AuthStorage.getHouseholdId();
      if (householdId == null || householdId.isEmpty) {
        final households = await _householdService.fetchHouseholds();
        if (households.isEmpty) {
          throw Exception('No households found for this user');
        }
        // For now, just pick the first one
        householdId = households.first.id;
        await AuthStorage.setHouseholdId(householdId);
      }

      // 2. Now we can safely fetch transactions
      final result = await _transactionService.fetchTransactions(useCache: !force);
      _transactions = result;
      // Sort by creation time (newest first)
      _transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load transactions for a specific account with date range
  Future<void> loadForAccountWithDateRange({
    required String accountId,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool force = false,
  }) async {
    if (_isLoading) return;
    // REMOVE this:
    // if (!force && _transactions.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _transactionService.fetchTransactionsForAccountWithDateRange(
        accountId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        useCache: !force,
      );
      _transactions = result;
      _transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Force reload from backend (no cache).
  Future<void> refresh() => load(force: true);

  /// Force reload for specific account with date range
  Future<void> refreshForAccountWithDateRange({
    required String accountId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    await loadForAccountWithDateRange(
      accountId: accountId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      force: true,
    );
  }

  /// Set the transaction type filter
  void setFilter(String type) {
    if (_typeFilter == type) return;
    _typeFilter = type;
    notifyListeners();
  }

  /// Create a new transaction and refresh data.
  Future<void> createTransaction({
    required String type,
    required String accountId,
    required String categoryId,
    required String amount,
    required DateTime date,
    String? description,
  }) async {
    await _transactionService.createTransaction(
      type: type,
      accountId: accountId,
      categoryId: categoryId,
      amount: amount,
      date: date,
      description: description,
    );

    await refresh();
  }

  /// Update an existing transaction and refresh.
  Future<void> updateTransaction({
    required String transactionId,
    required String type,
    required String accountId,
    required String categoryId,
    required String amount,
    required DateTime date,
    String? description,
  }) async {
    await _transactionService.updateTransaction(
      transactionId: transactionId,
      type: type,
      accountId: accountId,
      categoryId: categoryId,
      amount: amount,
      date: date,
      description: description,
    );

    await refresh();
  }

  /// Delete a transaction and refresh.
  Future<void> deleteTransaction(String transactionId) async {
    await _transactionService.deleteTransaction(transactionId);
    await refresh();
  }

  /// Create a new transfer and refresh.
  Future<void> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required String amount,
    required DateTime date,
    String? description,
    String? categoryId,
    bool mustBeSameGroup = false,
  }) async {
    await _transactionService.createTransfer(
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amount: amount,
      date: date,
      description: description,
      categoryId: categoryId,
      mustBeSameGroup: mustBeSameGroup,
    );

    await refresh();
  }

  /// Delete a transfer and refresh.
  Future<void> deleteTransfer(String transferGroupId) async {
    await _transactionService.deleteTransfer(transferGroupId);
    await refresh();
  }
}