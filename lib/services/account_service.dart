import 'dart:convert';
import 'api_client.dart';
import '../models/account_group.dart';

class AccountService {
  /// POST /api/accounts
  /// body: {
  ///   "name": "Emergency Savings",
  ///   "groupId": "grp789xyz012uvw",
  ///   "currency": "IDR",
  ///   "startingBalance": "5000.00",
  ///   "isArchived": false,
  ///   "scope": "PERSONAL",
  ///   "ownerUserId": "usr456def789ghi"
  /// }
  Future<AccountModel> createAccount({
    required String name,
    required String groupId,
    required String currency,
    required String startingBalance,
    bool isArchived = false,
    String scope = "PERSONAL",
    required String ownerUserId,
  }) async {
    final body = {
      'name': name,
      'groupId': groupId,
      'currency': currency,
      'startingBalance': startingBalance,
      'isArchived': isArchived,
      'scope': scope,
      'ownerUserId': ownerUserId,
    };

    final res = await ApiClient.post('/api/accounts', body);

    if (res.statusCode != 201 && res.statusCode != 200) {
      String errorMessage = 'Failed to add account';
      try {
        final errorData = jsonDecode(res.body) as Map<String, dynamic>?;
        if (errorData != null && errorData['message'] != null) {
          errorMessage = errorData['message'] as String;
        }
      } catch (e) {
        // If we can't parse the error, use the status code and body
        errorMessage = 'Failed to add account (${res.statusCode}): ${res.body}';
      }
      throw Exception(errorMessage);
    }

    try {
      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;
      return AccountModel.fromJson(data);
    } catch (e) {
      throw Exception('Failed to parse account response: $e');
    }
  }

  /// PUT /api/accounts/YOUR_ACCOUNT_ID
  /// body: {
  ///   "name": "Updated Account Name",
  ///   "currency": "EUR",
  ///   "isArchived": true
  /// }
  Future<AccountModel> updateAccount({
    required String accountId,
    required String name,
    required String currency,
    bool? isArchived,
  }) async {
    final body = {
      'name': name,
      'currency': currency,
      if (isArchived != null) 'isArchived': isArchived,
    };

    final res = await ApiClient.put('/api/accounts/$accountId', body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      String errorMessage = 'Failed to update account';
      try {
        final errorData = jsonDecode(res.body) as Map<String, dynamic>?;
        if (errorData != null && errorData['message'] != null) {
          errorMessage = errorData['message'] as String;
        }
      } catch (e) {
        // If we can't parse the error, use the status code and body
        errorMessage = 'Failed to update account (${res.statusCode}): ${res.body}';
      }
      throw Exception(errorMessage);
    }

    try {
      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;
      return AccountModel.fromJson(data);
    } catch (e) {
      throw Exception('Failed to parse account response: $e');
    }
  }

  /// DELETE /api/accounts/YOUR_ACCOUNT_ID
  Future<void> deleteAccount(String accountId) async {
    final res = await ApiClient.delete('/api/accounts/$accountId');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to delete account: ${res.body}');
    }
  }

  /// PUT /api/accounts/reorder
  /// body: { "accountIds": ["id1", "id2", "id3"] }
  Future<void> reorderAccounts({
    required List<String> accountIds,
  }) async {
    final body = {
      'accountIds': accountIds,
    };

    final res = await ApiClient.put('/api/accounts/reorder', body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to reorder accounts: ${res.body}');
    }
  }
}