import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/api_error.dart';

class LoginResponse {
  final String token;
  final Map<String, dynamic> user;

  LoginResponse({
    required this.token,
    required this.user,
  });
}

class AuthService {
  static const String _baseUrl = ApiConfig.baseUrl;

  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/mobile/login');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['token']?.toString() ?? '';
      final user = data['user'] as Map<String, dynamic>? ?? {};

      return LoginResponse(token: token, user: user);
    } else {
      // Use the same error handling pattern as ApiClient
      final msg = ApiErrorUtils.extractMessage(response);
      throw Exception(msg);
    }
  }
}
