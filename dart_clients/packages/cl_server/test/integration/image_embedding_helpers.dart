import 'dart:async';
import 'dart:io';

import 'package:cl_server/cl_server.dart';
import '../fixtures/test_image_loader.dart';

/// Test configuration for image embedding workflow tests
class ImageEmbeddingTestConfig {
  final String authBaseUrl;
  final String mediaStoreBaseUrl;
  final String inferenceBaseUrl;
  final Duration pollInterval;
  final Duration maxPollDuration;
  final bool useMqtt;

  ImageEmbeddingTestConfig({
    this.authBaseUrl = 'http://localhost:8000',
    this.mediaStoreBaseUrl = 'http://localhost:8001',
    this.inferenceBaseUrl = 'http://localhost:8002',
    this.pollInterval = const Duration(seconds: 2),
    this.maxPollDuration = const Duration(seconds: 120),
    this.useMqtt = false,
  });
}

/// Test user credentials
class TestUser {
  final String username;
  final String password;
  final bool requiresPermission;

  const TestUser({
    required this.username,
    required this.password,
    this.requiresPermission = true,
  });

  static const TestUser admin = TestUser(
    username: 'admin',
    password: 'admin',
  );

  static const TestUser testUser = TestUser(
    username: 'testuser',
    password: 'testuser123',
  );

  static const TestUser noPermissionUser = TestUser(
    username: 'noPermissionUser',
    password: 'password123',
    requiresPermission: false,
  );
}

/// Helper class for image embedding workflow tests
class ImageEmbeddingTestHelper {
  final ImageEmbeddingTestConfig config;

  late AuthClient authClient;
  late MediaStoreClient mediaStoreClient;
  late InferenceClient inferenceClient;

  ImageEmbeddingTestHelper({ImageEmbeddingTestConfig? config})
      : config = config ?? ImageEmbeddingTestConfig();

  /// Initialize clients
  Future<void> initialize() async {
    authClient = AuthClient(baseUrl: config.authBaseUrl);
    mediaStoreClient = MediaStoreClient(baseUrl: config.mediaStoreBaseUrl);
    inferenceClient = InferenceClient(baseUrl: config.inferenceBaseUrl);

    // Initialize image loader
    await TestImageLoader.initialize();
  }

  /// Authenticate with test user
  Future<Token> authenticate(TestUser user) async {
    try {
      return await authClient.login(user.username, user.password);
    } catch (e) {
      throw Exception('Authentication failed for ${user.username}: $e');
    }
  }

  /// Authenticate as admin
  Future<Token> authenticateAsAdmin() async {
    return authenticate(TestUser.admin);
  }

  /// Upload test image and return media_store_id (with collection)
  Future<String> uploadTestImage(
    Token token, {
    TestImage? image,
    int? collectionId,
  }) async {
    try {
      image ??= await TestImageLoader.getPrimaryImage();
      if (image == null) {
        throw Exception('No test image available');
      }

      // Create collection if not provided
      collectionId ??= (await mediaStoreClient.createCollection(
        token: token.accessToken,
        label: 'Test Collection - ${DateTime.now()}',
      ))
          .id;

      final entity = await mediaStoreClient.createEntity(
        token: token.accessToken,
        file: File(image.absolutePath),
        label: 'Test image - ${DateTime.now()}',
        parentId: collectionId,
      );

      return entity.id.toString();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Upload multiple test images
  Future<List<String>> uploadMultipleTestImages(
    Token token,
    int count,
  ) async {
    try {
      final mediaStoreIds = <String>[];
      final images = await TestImageLoader.getRandomImages(count);

      // Create single collection for all images
      final collection = await mediaStoreClient.createCollection(
        token: token.accessToken,
        label: 'Test Collection - ${DateTime.now()}',
      );

      for (final image in images) {
        final entity = await mediaStoreClient.createEntity(
          token: token.accessToken,
          file: File(image.absolutePath),
          label: 'Test image - ${DateTime.now()}',
          parentId: collection.id,
        );
        mediaStoreIds.add(entity.id.toString());
      }

      return mediaStoreIds;
    } catch (e) {
      throw Exception('Failed to upload multiple images: $e');
    }
  }

  /// Submit embedding job
  Future<Job> submitEmbeddingJob(
    Token token,
    String mediaStoreId, {
    int priority = 5,
  }) async {
    try {
      return await inferenceClient.createJob(
        token: token.accessToken,
        mediaStoreId: mediaStoreId,
        taskType: 'image_embedding',
        priority: priority,
      );
    } catch (e) {
      throw Exception('Failed to submit embedding job: $e');
    }
  }

  /// Wait for job completion by polling
  Future<Job?> waitForJobCompletion(
    String jobId, {
    Duration? pollInterval,
    Duration? maxDuration,
  }) async {
    pollInterval ??= config.pollInterval;
    maxDuration ??= config.maxPollDuration;

    final startTime = DateTime.now();

    while (true) {
      try {
        final job = await inferenceClient.getJob(jobId);

        if (job.status == 'completed' || job.status == 'error') {
          return job;
        }

        final elapsed = DateTime.now().difference(startTime);
        if (elapsed > maxDuration) {
          return null;
        }

        await Future.delayed(pollInterval);
      } catch (e) {
        final elapsed = DateTime.now().difference(startTime);
        if (elapsed > maxDuration) {
          return null;
        }
        await Future.delayed(pollInterval);
      }
    }
  }

  /// Complete workflow: upload image -> submit job -> wait for completion
  Future<Job?> completeImageEmbeddingWorkflow(
    Token token, {
    TestImage? image,
    int jobPriority = 5,
  }) async {
    try {
      // Upload image
      final mediaStoreId = await uploadTestImage(token, image: image);

      // Submit job
      final job = await submitEmbeddingJob(
        token,
        mediaStoreId,
        priority: jobPriority,
      );

      // Wait for completion
      final completedJob = await waitForJobCompletion(job.jobId);

      return completedJob;
    } catch (e) {
      throw Exception('Image embedding workflow failed: $e');
    }
  }

  /// Clean up: delete job and media (for test cleanup)
  Future<void> cleanup({
    required Token token,
    required String jobId,
    required String mediaStoreId,
  }) async {
    try {
      // Delete job
      await inferenceClient.deleteJob(token: token.accessToken, jobId: jobId);

      // Delete media
      await mediaStoreClient.deleteEntity(
        token: token.accessToken,
        entityId: int.parse(mediaStoreId),
      );
    } catch (e) {
      // Log but don't fail - best effort cleanup
      print('Warning: Cleanup failed: $e');
    }
  }

  /// Get job status without waiting
  Future<Job> getJobStatus(String jobId) async {
    return await inferenceClient.getJob(jobId);
  }

  /// Check if job is in terminal state
  Future<bool> isJobComplete(String jobId) async {
    final job = await getJobStatus(jobId);
    return job.status == 'completed' || job.status == 'error';
  }

  /// Get job error message if job failed
  Future<String?> getJobErrorMessage(String jobId) async {
    final job = await getJobStatus(jobId);
    return job.errorMessage;
  }
}

/// Context for managing test resources (images, jobs, media)
class ImageEmbeddingTestContext {
  final Map<String, String> uploadedMedia =
      {}; // jobId -> mediaStoreId mapping
  final List<String> createdJobs = [];
  final ImageEmbeddingTestHelper helper;

  ImageEmbeddingTestContext(this.helper);

  /// Register uploaded media for cleanup
  void registerMedia(String mediaStoreId) {
    uploadedMedia[DateTime.now().millisecondsSinceEpoch.toString()] =
        mediaStoreId;
  }

  /// Register created job for cleanup
  void registerJob(String jobId) {
    createdJobs.add(jobId);
  }

  /// Clean up all created resources
  Future<void> cleanup(Token token) async {
    // Delete jobs
    for (final jobId in createdJobs) {
      try {
        await helper.inferenceClient.deleteJob(
          token: token.accessToken,
          jobId: jobId,
        );
      } catch (e) {
        print('Warning: Failed to delete job $jobId: $e');
      }
    }

    // Delete media
    for (final mediaId in uploadedMedia.values) {
      try {
        await helper.mediaStoreClient.deleteEntity(
          token: token.accessToken,
          entityId: int.parse(mediaId),
        );
      } catch (e) {
        print('Warning: Failed to delete media $mediaId: $e');
      }
    }

    createdJobs.clear();
    uploadedMedia.clear();
  }
}
