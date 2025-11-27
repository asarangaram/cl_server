/// Service statistics response from admin endpoint
class StatsResponse {
  final int queueSize;
  final Map<String, int> jobs;
  final Map<String, dynamic> storage;

  StatsResponse({
    required this.queueSize,
    required this.jobs,
    required this.storage,
  });

  /// Create StatsResponse from JSON response
  factory StatsResponse.fromJson(Map<String, dynamic> json) {
    return StatsResponse(
      queueSize: json['queue_size'] as int,
      jobs: Map<String, int>.from(json['jobs'] as Map),
      storage: json['storage'] as Map<String, dynamic>,
    );
  }

  /// Convert StatsResponse to JSON
  Map<String, dynamic> toJson() {
    return {
      'queue_size': queueSize,
      'jobs': jobs,
      'storage': storage,
    };
  }

  @override
  String toString() =>
      'StatsResponse(queueSize: $queueSize, jobs: $jobs, storage: $storage)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatsResponse &&
          runtimeType == other.runtimeType &&
          queueSize == other.queueSize &&
          jobs == other.jobs &&
          storage == other.storage;

  @override
  int get hashCode => queueSize.hashCode ^ jobs.hashCode ^ storage.hashCode;
}
