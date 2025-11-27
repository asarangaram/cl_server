/// Decoded JWT token data extracted from the token payload
class TokenData {
  /// User ID from the 'sub' claim
  final String userId;

  /// List of permission strings
  final List<String> permissions;

  /// Whether the user is an admin
  final bool isAdmin;

  /// Token expiration timestamp
  final DateTime expiresAt;

  TokenData({
    required this.userId,
    required this.permissions,
    required this.isAdmin,
    required this.expiresAt,
  });

  /// Check if the token has expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Get the remaining duration until token expires
  Duration get remainingDuration {
    final now = DateTime.now();
    if (isExpired) {
      return Duration.zero;
    }
    return expiresAt.difference(now);
  }

  /// Check if user has a specific permission
  bool hasPermission(String permission) {
    if (isAdmin) return true; // Admin has all permissions
    return permissions.contains(permission);
  }

  @override
  String toString() {
    return 'TokenData('
        'userId: $userId, '
        'isAdmin: $isAdmin, '
        'permissions: $permissions, '
        'expiresAt: $expiresAt, '
        'isExpired: $isExpired)';
  }
}
