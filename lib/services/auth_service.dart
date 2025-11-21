import 'dart:convert';
import 'package:http/http.dart' as http;

class LoginResponse {
  final String token;
  final Map<String, dynamic> user;

  LoginResponse({
    required this.token,
    required this.user,
  });
}

class AuthService {
  static const String _baseUrl = 'http://192.168.18.129:7777';

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
      // You can improve error handling later
      throw Exception('Login failed: ${response.statusCode} ${response.body}');
    }
  }
}
