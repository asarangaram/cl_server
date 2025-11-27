/// Cleanup operation response from admin endpoint
class CleanupResponse {
  final int jobsDeleted;
  final int filesDeleted;
  final int queueEntriesRemoved;

  CleanupResponse({
    required this.jobsDeleted,
    required this.filesDeleted,
    required this.queueEntriesRemoved,
  });

  /// Create CleanupResponse from JSON response
  factory CleanupResponse.fromJson(Map<String, dynamic> json) {
    return CleanupResponse(
      jobsDeleted: json['jobs_deleted'] as int,
      filesDeleted: json['files_deleted'] as int,
      queueEntriesRemoved: json['queue_entries_removed'] as int,
    );
  }

  /// Convert CleanupResponse to JSON
  Map<String, dynamic> toJson() {
    return {
      'jobs_deleted': jobsDeleted,
      'files_deleted': filesDeleted,
      'queue_entries_removed': queueEntriesRemoved,
    };
  }

  @override
  String toString() =>
      'CleanupResponse(jobsDeleted: $jobsDeleted, filesDeleted: $filesDeleted, queueEntriesRemoved: $queueEntriesRemoved)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CleanupResponse &&
          runtimeType == other.runtimeType &&
          jobsDeleted == other.jobsDeleted &&
          filesDeleted == other.filesDeleted &&
          queueEntriesRemoved == other.queueEntriesRemoved;

  @override
  int get hashCode =>
      jobsDeleted.hashCode ^ filesDeleted.hashCode ^ queueEntriesRemoved.hashCode;
}
