// lib/services/api_client.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../storage/auth_storage.dart';
import 'cache_service.dart';
import '../pages/login_page.dart';
import '../config/api_config.dart';
import '../utils/api_error.dart';

class ApiClient {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'ApiClientNavigatorKey');

  static const String baseUrl = ApiConfig.baseUrl;

  static final CacheService _cache = CacheService();

  /// Keeps track of identical in-flight GET requests (by cache key)
  static final Map<String, Future<http.Response>> _inFlightRequests = {};

  /// Build base headers (Authorization, Household, etc.)
  static Future<Map<String, String>> _buildHeaders() async {
    final token = await AuthStorage.getToken();
    final householdId = await AuthStorage.getHouseholdId();

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (householdId != null && householdId.isNotEmpty) {
      headers['X-Household-ID'] = householdId;
    }

    return headers;
  }

  /// GET with optional caching + in-flight de-duplication
  static Future<http.Response> get(
    String endpoint, {
    bool useCache = true,
    Duration? cacheExpiration,
  }) async {
    final requestKey = CacheService.generateKey(endpoint, null);

    // Reuse in-flight request if identical
    if (_inFlightRequests.containsKey(requestKey)) {
      return _inFlightRequests[requestKey]!;
    }

    // Read from cache first
    if (useCache) {
      final cachedResponse = _cache.get<http.Response>(requestKey);
      if (cachedResponse != null) {
        return cachedResponse;
      }
    }

    // Create the actual request
    final requestFuture = _executeGetRequest(endpoint);
    _inFlightRequests[requestKey] = requestFuture;

    try {
      final response = await requestFuture;

      // Centralized status + error handling
      final processed = _handleResponse(
        endpoint: endpoint,
        response: response,
        invalidateRelatedCache: false, // GET does not invalidate anything
      );

      // Cache successful responses
      if (useCache) {
        _cache.put(requestKey, processed, expiration: cacheExpiration);
      }

      return processed;
    } finally {
      _inFlightRequests.remove(requestKey);
    }
  }

  /// Internal low-level GET (no error handling here)
  static Future<http.Response> _executeGetRequest(String endpoint) async {
    final headers = await _buildHeaders();
    final uri = Uri.parse('$baseUrl$endpoint');
    return http.get(uri, headers: headers);
  }

  /// POST with centralized error handling + cache invalidation
  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final headers = await _buildHeaders();
    final uri = Uri.parse('$baseUrl$endpoint');

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    return _handleResponse(
      endpoint: endpoint,
      response: response,
      invalidateRelatedCache: true,
    );
  }

  /// PUT with centralized error handling + cache invalidation
  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final headers = await _buildHeaders();
    final uri = Uri.parse('$baseUrl$endpoint');

    final response = await http.put(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    return _handleResponse(
      endpoint: endpoint,
      response: response,
      invalidateRelatedCache: true,
    );
  }

  /// DELETE with centralized error handling + cache invalidation
  static Future<http.Response> delete(String endpoint) async {
    final headers = await _buildHeaders();
    final uri = Uri.parse('$baseUrl$endpoint');

    final response = await http.delete(uri, headers: headers);

    return _handleResponse(
      endpoint: endpoint,
      response: response,
      invalidateRelatedCache: true,
    );
  }

  /// Central place to:
  /// - Handle 401 (auth error + redirect)
  /// - Extract clean error messages via ApiErrorUtils
  /// - Invalidate cache for mutating requests
  static http.Response _handleResponse({
    required String endpoint,
    required http.Response response,
    required bool invalidateRelatedCache,
  }) {
    final status = response.statusCode;

    // 401 → auth expired / invalid
    if (status == 401) {
      _handleAuthError(response);
      throw Exception('Unauthorized. Please log in again.');
    }

    // Non-2xx → error; extract message consistently
    if (status < 200 || status >= 300) {
      final msg = ApiErrorUtils.extractMessage(response);
      throw Exception(msg);
    }

    // Successful mutation → invalidate related cache
    if (invalidateRelatedCache) {
      _invalidateRelatedCache(endpoint);
    }

    return response;
  }

  /// Invalidate cache entries related to the modified endpoint.
  /// For now we just clear everything (simple & safe).
  static void _invalidateRelatedCache(String endpoint) {
    _cache.clear();
  }

  /// Manually clear cache for specific endpoint
  static void clearCacheForEndpoint(String endpoint) {
    final key = CacheService.generateKey(endpoint, null);
    _cache.remove(key);
  }

  /// Clear all cache
  static void clearAllCache() {
    _cache.clear();
  }

  /// Handle authentication errors and redirect to login
  static void _handleAuthError(http.Response response) {
    // Optionally inspect response.body here if needed
    AuthStorage.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    });
  }
}
