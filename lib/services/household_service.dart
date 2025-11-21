// lib/services/household_service.dart
import 'dart:convert';

import 'api_client.dart';
import '../models/household.dart';

class HouseholdService {
  Future<List<Household>> fetchHouseholds() async {
    // If this fails (non-2xx, 401, etc.), ApiClient will already throw
    final res = await ApiClient.get('/api/households');

    final List<dynamic> jsonList = jsonDecode(res.body) as List<dynamic>;

    return jsonList
        .map((item) => Household.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
