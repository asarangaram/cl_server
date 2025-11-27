/// Configuration response for media store admin settings
class ConfigResponse {
  final bool readAuthEnabled;
  final DateTime? updatedAt;
  final int? updatedBy;

  ConfigResponse({
    required this.readAuthEnabled,
    this.updatedAt,
    this.updatedBy,
  });

  /// Create ConfigResponse from JSON response
  factory ConfigResponse.fromJson(Map<String, dynamic> json) {
    return ConfigResponse(
      readAuthEnabled: json['read_auth_enabled'] as bool,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      updatedBy: json['updated_by'] as int?,
    );
  }

  /// Convert ConfigResponse to JSON
  Map<String, dynamic> toJson() {
    return {
      'read_auth_enabled': readAuthEnabled,
      'updated_at': updatedAt?.toIso8601String(),
      'updated_by': updatedBy,
    };
  }

  @override
  String toString() {
    return 'ConfigResponse(readAuthEnabled: $readAuthEnabled, updatedAt: $updatedAt, updatedBy: $updatedBy)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfigResponse &&
          runtimeType == other.runtimeType &&
          readAuthEnabled == other.readAuthEnabled &&
          updatedAt == other.updatedAt &&
          updatedBy == other.updatedBy;

  @override
  int get hashCode =>
      readAuthEnabled.hashCode ^ updatedAt.hashCode ^ updatedBy.hashCode;
}
