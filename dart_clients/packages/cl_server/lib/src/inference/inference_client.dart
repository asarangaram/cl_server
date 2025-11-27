import '../core/http_client.dart';
import '../core/exceptions.dart';
import 'models/job.dart';
import 'models/health_response.dart';
import 'models/stats_response.dart';
import 'models/cleanup_response.dart';

/// Client for CL Server Inference Service
/// Provides stateless methods for managing AI inference jobs and monitoring
class InferenceClient {
  final CLHttpClient _httpClient;

  InferenceClient({
    required String baseUrl,
    CLHttpClient? httpClient,
    Duration? requestTimeout,
  }) : _httpClient = httpClient ??
      CLHttpClient(
        baseUrl: baseUrl,
        requestTimeout: requestTimeout ?? const Duration(seconds: 30),
      );

  // ============================================================
  // CORE JOB ENDPOINTS
  // ============================================================

  /// Create a new inference job
  ///
  /// Parameters:
  /// - token: JWT token with ai_inference_support permission
  /// - mediaStoreId: ID of media entity to process
  /// - taskType: Task to perform (image_embedding, face_detection, face_embedding)
  /// - priority: Job priority (0-10, default 5, higher is more urgent)
  ///
  /// Returns: Created Job with pending status
  ///
  /// Throws:
  /// - ValidationException (400): Invalid task_type or priority out of range
  /// - AuthenticationException (401): Missing or invalid token
  /// - AuthorizationException (403): Missing ai_inference_support permission
  /// - DuplicateResourceException (409): Job already exists for this media_store_id + task_type
  Future<Job> createJob({
    required String token,
    required String mediaStoreId,
    required String taskType,
    int priority = 5,
  }) async {
    try {
      _validateToken(token);

      if (priority < 0 || priority > 10) {
        throw ValidationException(
          message: 'Priority must be between 0 and 10, got $priority',
        );
      }

      final validTaskTypes = ['image_embedding', 'face_detection', 'face_embedding'];
      if (!validTaskTypes.contains(taskType)) {
        throw ValidationException(
          message: 'Invalid task_type: $taskType. Must be one of: $validTaskTypes',
        );
      }

      final body = {
        'media_store_id': mediaStoreId,
        'priority': priority,
      };

      final response = await _httpClient.post(
        '/job/$taskType',
        body: body,
        token: token,
      );

      if (response is Map<String, dynamic>) {
        return Job.fromJson(response);
      }

      throw ValidationException(
        message: 'Unexpected response format for job creation',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to create inference job: $e',
      );
    }
  }

  /// Get the status of an inference job
  ///
  /// This endpoint does not require authentication - the job_id acts as a capability token.
  ///
  /// Parameters:
  /// - jobId: ID of the job to retrieve
  ///
  /// Returns: Current Job status with results if completed
  ///
  /// Throws:
  /// - NotFoundException (404): Job not found
  Future<Job> getJob(String jobId) async {
    try {
      final response = await _httpClient.get('/job/$jobId');

      if (response is Map<String, dynamic>) {
        return Job.fromJson(response);
      }

      throw ValidationException(
        message: 'Unexpected response format for job retrieval',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to get inference job: $e',
      );
    }
  }

  /// Delete an inference job
  ///
  /// Parameters:
  /// - token: JWT token with ai_inference_support permission
  /// - jobId: ID of the job to delete
  ///
  /// Returns: void (HTTP 204 No Content)
  ///
  /// Throws:
  /// - AuthenticationException (401): Missing or invalid token
  /// - AuthorizationException (403): Missing ai_inference_support permission
  /// - NotFoundException (404): Job not found
  Future<void> deleteJob({
    required String token,
    required String jobId,
  }) async {
    try {
      _validateToken(token);

      await _httpClient.delete('/job/$jobId', token: token);
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to delete inference job: $e',
      );
    }
  }

  // ============================================================
  // ADMIN ENDPOINTS
  // ============================================================

  /// Get service health status
  ///
  /// This endpoint does not require authentication.
  ///
  /// Returns: Health status with database, worker, and queue information
  Future<HealthResponse> healthCheck() async {
    try {
      final response = await _httpClient.get('/health');

      if (response is Map<String, dynamic>) {
        return HealthResponse.fromJson(response);
      }

      throw ValidationException(
        message: 'Unexpected response format for health check',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to check health: $e',
      );
    }
  }

  /// Get service statistics
  ///
  /// Parameters:
  /// - token: JWT token with admin permission
  ///
  /// Returns: Service statistics including queue size and job counts by status
  ///
  /// Throws:
  /// - AuthenticationException (401): Missing or invalid token
  /// - AuthorizationException (403): Missing admin permission
  Future<StatsResponse> getStats({
    required String token,
  }) async {
    try {
      _validateToken(token);

      final response = await _httpClient.get('/admin/stats', token: token);

      if (response is Map<String, dynamic>) {
        return StatsResponse.fromJson(response);
      }

      throw ValidationException(
        message: 'Unexpected response format for stats',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to get service stats: $e',
      );
    }
  }

  /// Cleanup old jobs and files
  ///
  /// Parameters:
  /// - token: JWT token with admin permission
  /// - olderThanSeconds: Only delete jobs older than this (optional)
  /// - status: Filter by job status: pending, processing, completed, error, sync_failed, all (default: all)
  /// - removeResults: Whether to remove job results (default: true)
  /// - removeQueue: Whether to remove queue entries (default: true)
  /// - removeOrphanedFiles: Whether to remove files without associated jobs (default: false)
  ///
  /// Returns: Cleanup summary with counts of deleted items
  ///
  /// Throws:
  /// - AuthenticationException (401): Missing or invalid token
  /// - AuthorizationException (403): Missing admin permission
  Future<CleanupResponse> cleanup({
    required String token,
    int? olderThanSeconds,
    String status = 'all',
    bool removeResults = true,
    bool removeQueue = true,
    bool removeOrphanedFiles = false,
  }) async {
    try {
      _validateToken(token);

      final body = {
        if (olderThanSeconds != null) 'older_than_seconds': olderThanSeconds,
        'status': status,
        'remove_results': removeResults,
        'remove_queue': removeQueue,
        'remove_orphaned_files': removeOrphanedFiles,
      };

      final response = await _httpClient.delete(
        '/admin/cleanup',
        body: body,
        token: token,
      );

      if (response is Map<String, dynamic>) {
        return CleanupResponse.fromJson(response);
      }

      throw ValidationException(
        message: 'Unexpected response format for cleanup',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to cleanup service: $e',
      );
    }
  }

  // ============================================================
  // UTILITY METHODS
  // ============================================================

  /// Validate that a token is present and non-empty
  void _validateToken(String token) {
    if (token.isEmpty) {
      throw AuthenticationException(
        message: 'Token is required but was empty',
      );
    }
  }

  /// Close the HTTP client and release resources
  void close() {
    _httpClient.close();
  }
}
