/// Inference job response model
/// Represents a submitted inference job with status and results
class Job {
  final String jobId;
  final String taskType;
  final String mediaStoreId;
  final String status;
  final int priority;
  final int createdAt;
  final int? startedAt;
  final int? completedAt;
  final String? errorMessage;
  final Map<String, dynamic>? result;

  Job({
    required this.jobId,
    required this.taskType,
    required this.mediaStoreId,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.errorMessage,
    this.result,
  });

  /// Create Job from JSON response
  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      jobId: json['job_id'] as String,
      taskType: json['task_type'] as String,
      mediaStoreId: json['media_store_id'] as String,
      status: json['status'] as String,
      priority: json['priority'] as int,
      createdAt: json['created_at'] as int,
      startedAt: json['started_at'] as int?,
      completedAt: json['completed_at'] as int?,
      errorMessage: json['error_message'] as String?,
      result: json['result'] as Map<String, dynamic>?,
    );
  }

  /// Convert Job to JSON
  Map<String, dynamic> toJson() {
    return {
      'job_id': jobId,
      'task_type': taskType,
      'media_store_id': mediaStoreId,
      'status': status,
      'priority': priority,
      'created_at': createdAt,
      'started_at': startedAt,
      'completed_at': completedAt,
      'error_message': errorMessage,
      'result': result,
    };
  }

  @override
  String toString() =>
      'Job(jobId: $jobId, taskType: $taskType, status: $status, mediaStoreId: $mediaStoreId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Job &&
          runtimeType == other.runtimeType &&
          jobId == other.jobId &&
          taskType == other.taskType &&
          mediaStoreId == other.mediaStoreId &&
          status == other.status &&
          priority == other.priority &&
          createdAt == other.createdAt &&
          startedAt == other.startedAt &&
          completedAt == other.completedAt &&
          errorMessage == other.errorMessage &&
          result == other.result;

  @override
  int get hashCode =>
      jobId.hashCode ^
      taskType.hashCode ^
      mediaStoreId.hashCode ^
      status.hashCode ^
      priority.hashCode ^
      createdAt.hashCode ^
      startedAt.hashCode ^
      completedAt.hashCode ^
      errorMessage.hashCode ^
      result.hashCode;
}
