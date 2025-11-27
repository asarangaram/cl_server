import 'token_data.dart';

/// JWT token response from login endpoint
class Token {
  final String accessToken;
  final String tokenType; // "bearer"

  Token({
    required this.accessToken,
    required this.tokenType,
  });

  /// Create Token from JSON response
  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
    );
  }

  /// Convert Token to JSON
  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
    };
  }

  @override
  String toString() => 'Token(type: $tokenType, token: ${accessToken.substring(0, 20)}...)';
}
