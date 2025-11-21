import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiErrorUtils {
  /// Extracts a clean error message from an HTTP response.
  /// Priority:
  /// 1. If response JSON contains {"message": "..."} → return that
  /// 2. If response JSON contains {"error": "..."} → return that
  /// 3. If response body is plain text → return it
  /// 4. Otherwise → fallback to generic HTTP error message
  static String extractMessage(http.Response res) {
    final status = res.statusCode;

    try {
      final body = jsonDecode(res.body);
      
      if (body is Map<String, dynamic>) {
        if (body['message'] is String && body['message'].toString().trim().isNotEmpty) {
          return body['message'];
        }
        if (body['error'] is String && body['error'].toString().trim().isNotEmpty) {
          return body['error'];
        }
      }
    } catch (_) {
      // Ignore JSON parse error — fallback below
    }

    // If body is plain text (not JSON)
    if (res.body.isNotEmpty && !res.body.startsWith('{')) {
      return res.body.trim();
    }

    return 'Request failed (HTTP $status). Please try again.';
  }
}
