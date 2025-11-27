import 'dart:convert';
import '../core/models/token_data.dart';
import '../core/exceptions.dart';

/// Manages JWT token parsing and validation
/// Note: Does NOT verify token signatures, trusts server for validation
class TokenManager {
  /// Parse a JWT token and extract claims
  static TokenData parse(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        throw ValidationException(
          message: 'Invalid token format',
        );
      }

      // Decode payload (second part)
      final payload = _decodeBase64Url(parts[1]);
      final json = jsonDecode(payload) as Map<String, dynamic>;

      // Extract claims
      final userId = json['sub'] as String?;
      if (userId == null) {
        throw ValidationException(
          message: 'Missing "sub" claim in token',
        );
      }

      final permissions = List<String>.from(json['permissions'] as List? ?? []);
      final isAdmin = json['is_admin'] as bool? ?? false;
      final exp = json['exp'] as int?;

      if (exp == null) {
        throw ValidationException(
          message: 'Missing "exp" claim in token',
        );
      }

      // Convert Unix timestamp (seconds) to DateTime
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);

      return TokenData(
        userId: userId,
        permissions: permissions,
        isAdmin: isAdmin,
        expiresAt: expiresAt,
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw ValidationException(
        message: 'Failed to parse token: $e',
      );
    }
  }

  /// Try to parse a token, returns null if invalid
  static TokenData? tryParse(String token) {
    try {
      return parse(token);
    } catch (e) {
      return null;
    }
  }

  /// Check if a token is expired
  static bool isTokenExpired(String token) {
    try {
      final tokenData = parse(token);
      return tokenData.isExpired;
    } catch (e) {
      // If we can't parse, consider it expired
      return true;
    }
  }

  /// Get the JWT header
  static Map<String, dynamic> decodeHeader(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        throw ValidationException(
          message: 'Invalid token format',
        );
      }

      final header = _decodeBase64Url(parts[0]);
      return jsonDecode(header) as Map<String, dynamic>;
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw ValidationException(
        message: 'Failed to decode token header: $e',
      );
    }
  }

  /// Decode a base64url encoded string
  static String _decodeBase64Url(String input) {
    // Add padding if needed
    var output = input.replaceAll('-', '+').replaceAll('_', '/');
    final paddingNeeded = 4 - (output.length % 4);
    if (paddingNeeded != 4) {
      output += '=' * paddingNeeded;
    }

    try {
      return utf8.decode(base64.decode(output));
    } catch (e) {
      throw ValidationException(
        message: 'Failed to decode base64url: $e',
      );
    }
  }
}
