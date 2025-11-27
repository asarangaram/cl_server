/// User model representing a user in the authentication service
class User {
  final int id;
  final String username;
  final bool isAdmin;
  final bool isActive;
  final DateTime createdAt;
  final List<String> permissions;

  User({
    required this.id,
    required this.username,
    required this.isAdmin,
    required this.isActive,
    required this.createdAt,
    required this.permissions,
  });

  /// Create User from JSON response
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      isAdmin: json['is_admin'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      permissions: List<String>.from(json['permissions'] as List? ?? []),
    );
  }

  /// Convert User to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'is_admin': isAdmin,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'permissions': permissions,
    };
  }

  @override
  String toString() {
    return 'User('
        'id: $id, '
        'username: $username, '
        'isAdmin: $isAdmin, '
        'isActive: $isActive, '
        'createdAt: $createdAt, '
        'permissions: $permissions)';
  }
}
