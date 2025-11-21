import 'dart:convert';
import 'api_client.dart';

class SignUpResponse {
  final String token;
  final Map<String, dynamic> user;
  final String householdId;

  SignUpResponse({
    required this.token,
    required this.user,
    required this.householdId,
  });

  factory SignUpResponse.fromJson(Map<String, dynamic> json) {
    return SignUpResponse(
      token: json['token']?.toString() ?? '',
      user: json['user'] as Map<String, dynamic>? ?? {},
      householdId: json['householdId']?.toString() ?? '',
    );
  }
}

class UserService {
  /// POST /api/users
  /// body: { "email": "...", "password": "...", "name": "...", "householdName": "..." }
  Future<SignUpResponse> signUp({
    required String email,
    required String password,
    required String name,
    required String householdName,
  }) async {
    final body = {
      'email': email,
      'password': password,
      'name': name,
      'householdName': householdName,
    };

    final res = await ApiClient.post('/api/users', body);

    final Map<String, dynamic> data = jsonDecode(res.body) as Map<String, dynamic>;
    return SignUpResponse.fromJson(data);
  }
}