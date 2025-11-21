import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../models/household.dart';

class HouseholdService {
  Future<List<Household>> fetchHouseholds() async {
    final http.Response res = await ApiClient.get('/api/households');

    if (res.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(res.body) as List<dynamic>;
      return jsonList
          .map((item) => Household.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load households: ${res.body}');
    }
  }
}
