import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../models/transaction.dart';

class TransactionService {
  Future<List<TransactionModel>> fetchTransactions({bool useCache = true}) async {
    final http.Response res = await ApiClient.get('/api/transactions', useCache: useCache);

    final List<dynamic> jsonList = jsonDecode(res.body) as List<dynamic>;
    return jsonList
        .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<TransactionModel>> fetchTransactionsForAccount(String accountId, {bool useCache = true}) async {
    final http.Response res =
        await ApiClient.get('/api/transactions?accountId=$accountId', useCache: useCache);

    final List<dynamic> jsonList = jsonDecode(res.body) as List<dynamic>;
    return jsonList
        .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<TransactionModel>> fetchTransactionsForAccountWithDateRange(
    String accountId, {
    DateTime? dateFrom,
    DateTime? dateTo,
    bool useCache = true,
  }) async {
    List<String> params = [];
    
    // Only add accountId parameter if it's not empty
    if (accountId.isNotEmpty) {
      params.add('accountId=$accountId');
    }
    
    if (dateFrom != null) {
      final dateFromStr = '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
      params.add('dateFrom=$dateFromStr');
    }
    
    if (dateTo != null) {
      final dateToStr = '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
      params.add('dateTo=$dateToStr');
    }

    final queryString = params.isNotEmpty ? '?${params.join('&')}' : '';
    final url = '/api/transactions$queryString';
    
    final http.Response res = await ApiClient.get(url, useCache: useCache);
    
    final List<dynamic> jsonList = jsonDecode(res.body) as List<dynamic>;
    return jsonList
        .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 🔹 NEW: get a single transaction by ID
  Future<TransactionModel> fetchTransactionById(String id) async {
    final http.Response res = await ApiClient.get('/api/transactions/$id');

    final Map<String, dynamic> jsonMap =
        jsonDecode(res.body) as Map<String, dynamic>;
    return TransactionModel.fromJson(jsonMap);
  }

    /// Create a new transaction
  Future<void> createTransaction({
    required String type,        // 'INCOME' or 'EXPENSE'
    required String accountId,
    required String categoryId,
    required String amount,      // "5000", "150.50" (positive)
    required DateTime date,
    String? description,
  }) async {
    final body = <String, dynamic>{
      'amount': amount,
      'type': type,
      'accountId': accountId,
      'categoryId': categoryId,
      'date': date.toUtc().toIso8601String(),
    };

    if (description != null && description.trim().isNotEmpty) {
      body['description'] = description.trim();
    }

    // POST /api/transactions
    await ApiClient.post('/api/transactions', body);
  }

  /// Update an existing transaction
  Future<void> updateTransaction({
    required String transactionId,
    required String type,        // 'INCOME' or 'EXPENSE'
    required String accountId,
    required String categoryId,
    required String amount,      // "5000", "150.50" (positive)
    required DateTime date,
    String? description,
  }) async {
    final body = <String, dynamic>{
      'amount': amount,
      'type': type,
      'accountId': accountId,
      'categoryId': categoryId,
      'date': date.toUtc().toIso8601String(),
    };

    if (description != null && description.trim().isNotEmpty) {
      body['description'] = description.trim();
    }

    // PUT /api/transactions/YOUR_TRANSACTION_ID
    await ApiClient.put('/api/transactions/$transactionId', body);
  }

  /// Delete a transaction
  Future<void> deleteTransaction(String transactionId) async {
    // DELETE /api/transactions/YOUR_TRANSACTION_ID
    await ApiClient.delete('/api/transactions/$transactionId');
  }

  /// Create a new transfer
  Future<void> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required String amount,
    required DateTime date,
    String? description,
    String? categoryId,
    bool mustBeSameGroup = false,
  }) async {
    final body = <String, dynamic>{
      'fromAccountId': fromAccountId,
      'toAccountId': toAccountId,
      'amount': amount,
      'date': date.toUtc().toIso8601String(),
    };

    if (description != null && description.trim().isNotEmpty) {
      body['description'] = description.trim();
    }

    if (categoryId != null && categoryId.trim().isNotEmpty) {
      body['categoryId'] = categoryId.trim();
    }

    if (mustBeSameGroup) {
      body['mustBeSameGroup'] = true;
    }

    // POST /api/transfers
    await ApiClient.post('/api/transfers', body);
  }

  /// Delete a transfer (both transactions) using transfer group ID
  Future<void> deleteTransfer(String transferGroupId) async {
    // DELETE /api/transfers/YOUR_TRANSFER_GROUP_ID
    await ApiClient.delete('/api/transfers/$transferGroupId');
  }
}
