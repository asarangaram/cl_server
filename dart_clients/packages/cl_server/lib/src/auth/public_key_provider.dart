import '../core/http_client.dart';
import '../core/exceptions.dart';

/// Provides public key for token verification
/// Fetches from the /auth/public-key endpoint and caches in memory
class PublicKeyProvider {
  final CLHttpClient _httpClient;
  final Duration _cacheDuration;

  String? _cachedPublicKey;
  DateTime? _cacheTime;

  /// Create a PublicKeyProvider
  /// [cacheDuration] controls how long to cache the public key (default 1 hour)
  PublicKeyProvider(
    this._httpClient, {
    Duration cacheDuration = const Duration(hours: 1),
  }) : _cacheDuration = cacheDuration;

  /// Get the public key, fetching from server if not cached
  Future<String> getPublicKey() async {
    // Check if cached and not expired
    if (_cachedPublicKey != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!).inSeconds < _cacheDuration.inSeconds) {
        return _cachedPublicKey!;
      }
    }

    try {
      final response = await _httpClient.get('/auth/public-key');

      if (response is Map<String, dynamic>) {
        final publicKey = response['public_key'] as String?;
        if (publicKey == null) {
          throw CLServerException(
            message: 'Public key not found in response',
            responseBody: response,
          );
        }

        // Cache the key
        _cachedPublicKey = publicKey;
        _cacheTime = DateTime.now();

        return publicKey;
      } else {
        throw CLServerException(
          message: 'Unexpected response format for public key',
          responseBody: response,
        );
      }
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to fetch public key: $e',
        responseBody: e,
      );
    }
  }

  /// Clear the cached public key
  void clearCache() {
    _cachedPublicKey = null;
    _cacheTime = null;
  }

  /// Get the algorithm (currently always ES256)
  Future<String> getAlgorithm() async {
    try {
      final response = await _httpClient.get('/auth/public-key');

      if (response is Map<String, dynamic>) {
        return response['algorithm'] as String? ?? 'ES256';
      }
      return 'ES256';
    } catch (e) {
      // If we can't fetch, return default
      return 'ES256';
    }
  }
}
