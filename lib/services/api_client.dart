// lib/services/api_client.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../storage/auth_storage.dart';
import 'cache_service.dart';
import '../pages/login_page.dart';

class ApiClient {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'ApiClientNavigatorKey');
  static const String baseUrl = 'http://192.168.18.129:7777';
  static final CacheService _cache = CacheService();
  static final Map<String, Future<http.Response>> _inFlightRequests = {};

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

  static Future<http.Response> get(String endpoint, {bool useCache = true, Duration? cacheExpiration}) async {
    // Check if there's already an identical request in flight
    final requestKey = CacheService.generateKey(endpoint, null);
    if (_inFlightRequests.containsKey(requestKey)) {
      return _inFlightRequests[requestKey]!;
    }

    // Check cache first (only for GET requests)
    if (useCache) {
      final cachedResponse = _cache.get<http.Response>(requestKey);
      if (cachedResponse != null) {
        return cachedResponse;
      }
    }

    // Create the request
    final requestFuture = _executeGetRequest(endpoint);
    _inFlightRequests[requestKey] = requestFuture;

    try {
      final response = await requestFuture;
      
      // Cache successful responses
      if (useCache && response.statusCode >= 200 && response.statusCode < 300) {
        _cache.put(requestKey, response, expiration: cacheExpiration);
      }
      
      return response;
    } finally {
      // Clean up in-flight request
      _inFlightRequests.remove(requestKey);
    }
  }

  static Future<http.Response> _executeGetRequest(String endpoint) async {
    final headers = await _buildHeaders();
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.get(uri, headers: headers);
    _handleAuthError(response);
    return response;
  }

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
    
    _handleAuthError(response);
    
    // Invalidate related cache entries after successful POST
    if (response.statusCode >= 200 && response.statusCode < 300) {
      _invalidateRelatedCache(endpoint);
    }
    
    return response;
  }

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
    
    _handleAuthError(response);
    
    // Invalidate related cache entries after successful PUT
    if (response.statusCode >= 200 && response.statusCode < 300) {
      _invalidateRelatedCache(endpoint);
    }
    
    return response;
  }

  static Future<http.Response> delete(String endpoint) async {
    final headers = await _buildHeaders();
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.delete(uri, headers: headers);
    
    _handleAuthError(response);
    
    // Invalidate related cache entries after successful DELETE
    if (response.statusCode >= 200 && response.statusCode < 300) {
      _invalidateRelatedCache(endpoint);
    }
    
    return response;
  }

  /// Invalidate cache entries related to the modified endpoint
  static void _invalidateRelatedCache(String endpoint) {
    // Clear all cache for simplicity - in a more sophisticated implementation,
    // we could selectively invalidate only related endpoints
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
    if (response.statusCode == 401) {
      // Clear stored authentication data
      AuthStorage.clear();
      
      // Navigate to login page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigatorKey.currentContext != null) {
          Navigator.of(navigatorKey.currentContext!).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
      });
    }
  }
}
