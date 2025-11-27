import '../core/http_client.dart';
import '../core/models/token.dart';
import '../core/models/user.dart';
import '../core/models/token_data.dart';
import '../core/exceptions.dart';
import 'token_manager.dart';
import 'public_key_provider.dart';

/// Client for CL Server Authentication Service
/// Provides stateless methods for authentication and user management
class AuthClient {
  final CLHttpClient _httpClient;
  final PublicKeyProvider _publicKeyProvider;

  AuthClient({
    required String baseUrl,
    CLHttpClient? httpClient,
    Duration? requestTimeout,
  })  : _httpClient = httpClient ?? CLHttpClient(
          baseUrl: baseUrl,
          requestTimeout: requestTimeout ?? const Duration(seconds: 30),
        ),
        _publicKeyProvider = PublicKeyProvider(
          httpClient ?? CLHttpClient(
            baseUrl: baseUrl,
            requestTimeout: requestTimeout ?? const Duration(seconds: 30),
          ),
        );

  // ============================================================
  // LOGIN ENDPOINT
  // ============================================================

  /// Login with username and password
  /// Returns a Token that can be used for subsequent requests
  Future<Token> login(String username, String password) async {
    try {
      final body = <String, String>{
        'username': username,
        'password': password,
      };

      final response = await _httpClient.post('/auth/token', body: body, isFormData: true);

      if (response is Map<String, dynamic>) {
        return Token.fromJson(response);
      }

      throw ValidationException(
        message: 'Unexpected response format for login',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Login failed: $e',
      );
    }
  }

  // ============================================================
  // USER INFO ENDPOINTS
  // ============================================================

  /// Get the current authenticated user
  Future<User> getCurrentUser(String token) async {
    try {
      _validateToken(token);

      final response = await _httpClient.get('/users/me', token: token);

      if (response is Map<String, dynamic>) {
        return User.fromJson(response);
      }

      throw ValidationException(
        message: 'Unexpected response format for user info',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to get current user: $e',
      );
    }
  }

  // ============================================================
  // USER MANAGEMENT ENDPOINTS (ADMIN)
  // ============================================================

  /// Create a new user (admin only)
  Future<User> createUser({
    required String token,
    required String username,
    required String password,
    bool isAdmin = false,
    bool isActive = true,
    List<String> permissions = const [],
  }) async {
    try {
      _validateToken(token);

      final body = {
        'username': username,
        'password': password,
        'is_admin': isAdmin,
        'is_active': isActive,
        'permissions': permissions,
      };

      final response = await _httpClient.post('/users/', body: body, token: token);

      if (response is Map<String, dynamic>) {
        return User.fromJson(response);
      }

      throw ValidationException(
        message: 'Unexpected response format for user creation',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to create user: $e',
      );
    }
  }

  /// Get a list of users (admin only)
  Future<List<User>> listUsers({
    required String token,
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      _validateToken(token);

      final queryParams = {
        'skip': skip.toString(),
        'limit': limit.toString(),
      };

      final response = await _httpClient.get('/users/', token: token, queryParameters: queryParams);

      if (response is List) {
        return response.map((user) => User.fromJson(user as Map<String, dynamic>)).toList();
      }

      throw ValidationException(
        message: 'Unexpected response format for user list',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to list users: $e',
      );
    }
  }

  /// Get a specific user by ID (admin only)
  Future<User> getUser({
    required String token,
    required int userId,
  }) async {
    try {
      _validateToken(token);

      final response = await _httpClient.get('/users/$userId', token: token);

      if (response is Map<String, dynamic>) {
        return User.fromJson(response);
      }

      throw ValidationException(
        message: 'Unexpected response format for user info',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to get user: $e',
      );
    }
  }

  /// Update a user (admin only)
  Future<User> updateUser({
    required String token,
    required int userId,
    String? password,
    bool? isAdmin,
    bool? isActive,
    List<String>? permissions,
  }) async {
    try {
      _validateToken(token);

      final body = <String, dynamic>{};
      if (password != null) body['password'] = password;
      if (isAdmin != null) body['is_admin'] = isAdmin;
      if (isActive != null) body['is_active'] = isActive;
      if (permissions != null) body['permissions'] = permissions;

      if (body.isEmpty) {
        throw ValidationException(
          message: 'At least one field must be provided for update',
        );
      }

      final response = await _httpClient.put('/users/$userId', body: body, token: token);

      if (response is Map<String, dynamic>) {
        return User.fromJson(response);
      }

      throw ValidationException(
        message: 'Unexpected response format for user update',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to update user: $e',
      );
    }
  }

  /// Delete a user (admin only)
  Future<void> deleteUser({
    required String token,
    required int userId,
  }) async {
    try {
      _validateToken(token);

      await _httpClient.delete('/users/$userId', token: token);
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to delete user: $e',
      );
    }
  }

  // ============================================================
  // TOKEN PARSING UTILITIES
  // ============================================================

  /// Parse a token to extract token data
  TokenData parseToken(String token) {
    return TokenManager.parse(token);
  }

  /// Check if a token is expired
  bool isTokenExpired(String token) {
    return TokenManager.isTokenExpired(token);
  }

  /// Try to parse a token, returns null if invalid
  TokenData? tryParseToken(String token) {
    return TokenManager.tryParse(token);
  }

  // ============================================================
  // PUBLIC KEY ENDPOINT
  // ============================================================

  /// Get the public key for token verification
  Future<String> getPublicKey() async {
    return _publicKeyProvider.getPublicKey();
  }

  /// Clear the cached public key
  void clearPublicKeyCache() {
    _publicKeyProvider.clearCache();
  }

  // ============================================================
  // UTILITY METHODS
  // ============================================================

  /// Validate that a token is not expired
  void _validateToken(String token) {
    if (TokenManager.isTokenExpired(token)) {
      throw AuthenticationException(
        message: 'Token has expired',
      );
    }
  }

  /// Close the HTTP client
  void close() {
    _httpClient.close();
  }
}
