/// Health check response from inference service
class HealthResponse {
  final String status;
  final String database;
  final String worker;
  final int queueSize;

  HealthResponse({
    required this.status,
    required this.database,
    required this.worker,
    required this.queueSize,
  });

  /// Create HealthResponse from JSON response
  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    return HealthResponse(
      status: json['status'] as String,
      database: json['database'] as String,
      worker: json['worker'] as String,
      queueSize: json['queue_size'] as int,
    );
  }

  /// Convert HealthResponse to JSON
  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'database': database,
      'worker': worker,
      'queue_size': queueSize,
    };
  }

  @override
  String toString() =>
      'HealthResponse(status: $status, database: $database, worker: $worker, queueSize: $queueSize)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthResponse &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          database == other.database &&
          worker == other.worker &&
          queueSize == other.queueSize;

  @override
  int get hashCode => status.hashCode ^ database.hashCode ^ worker.hashCode ^ queueSize.hashCode;
}
