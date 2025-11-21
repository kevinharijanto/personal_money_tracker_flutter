import 'dart:collection';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, _CacheEntry> _cache = {};
  final Duration _defaultExpiration = const Duration(minutes: 5);

  /// Get cached data or null if not found or expired
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    
    return entry.data as T?;
  }

  /// Store data in cache with optional expiration time
  void put<T>(String key, T data, {Duration? expiration}) {
    _cache[key] = _CacheEntry(
      data: data,
      expirationTime: DateTime.now().add(expiration ?? _defaultExpiration),
    );
  }

  /// Remove specific entry from cache
  void remove(String key) {
    _cache.remove(key);
  }

  /// Clear all cache entries
  void clear() {
    _cache.clear();
  }

  /// Clear expired entries
  void clearExpired() {
    final now = DateTime.now();
    _cache.removeWhere((key, entry) => entry.expirationTime.isBefore(now));
  }

  /// Generate a cache key from URL and parameters
  static String generateKey(String baseUrl, Map<String, dynamic>? params) {
    if (params == null || params.isEmpty) return baseUrl;
    
    final sortedParams = SplayTreeMap<String, dynamic>.from(params);
    final paramString = sortedParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    
    return '$baseUrl?$paramString';
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime expirationTime;

  _CacheEntry({
    required this.data,
    required this.expirationTime,
  });

  bool get isExpired => DateTime.now().isAfter(expirationTime);
}