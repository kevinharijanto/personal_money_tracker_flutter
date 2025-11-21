import 'dart:convert';
import 'api_client.dart';
import '../models/account_group.dart';

class AccountGroupService {
  /// GET /api/account-groups
  Future<List<AccountGroup>> fetchAccountGroups({bool useCache = true}) async {
    final res = await ApiClient.get('/api/account-groups', useCache: useCache);

    final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map((e) => AccountGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/account-groups
  /// body: { "name": "...", "kind": "BANK_ACCOUNTS" }
  Future<AccountGroup> createAccountGroup({
    required String name,
    required String kind,
  }) async {
    final body = {
      'name': name,
      'kind': kind,
    };

    final res = await ApiClient.post('/api/account-groups', body);

    final Map<String, dynamic> data =
        jsonDecode(res.body) as Map<String, dynamic>;
    return AccountGroup.fromJson(data);
  }

  /// PUT /api/account-groups/YOUR_GROUP_ID
  /// body: { "name": "...", "kind": "BANK_ACCOUNTS" }
  Future<AccountGroup> updateAccountGroup({
    required String groupId,
    required String name,
    required String kind,
  }) async {
    final body = {
      'name': name,
      'kind': kind,
    };

    final res = await ApiClient.put('/api/account-groups/$groupId', body);

    final Map<String, dynamic> data =
        jsonDecode(res.body) as Map<String, dynamic>;
    return AccountGroup.fromJson(data);
  }

  /// DELETE /api/account-groups/YOUR_GROUP_ID
  Future<void> deleteAccountGroup(String groupId) async {
    await ApiClient.delete('/api/account-groups/$groupId');
  }
}
