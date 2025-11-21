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

    final Map<String, dynamic> data =
        jsonDecode(res.body) as Map<String, dynamic>;
    return AccountModel.fromJson(data);
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

    final Map<String, dynamic> data =
        jsonDecode(res.body) as Map<String, dynamic>;
    return AccountModel.fromJson(data);
  }

  /// DELETE /api/accounts/YOUR_ACCOUNT_ID
  Future<void> deleteAccount(String accountId) async {
    await ApiClient.delete('/api/accounts/$accountId');
  }

  /// PUT /api/accounts/reorder
  /// body: { "accountIds": ["id1", "id2", "id3"] }
  Future<void> reorderAccounts({
    required List<String> accountIds,
  }) async {
    final body = {
      'accountIds': accountIds,
    };

    await ApiClient.put('/api/accounts/reorder', body);
  }
}