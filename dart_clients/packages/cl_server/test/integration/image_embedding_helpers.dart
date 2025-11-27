import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cl_server/cl_server.dart';
import '../fixtures/test_image_loader.dart';

// Import MQTT listener from inference client
import 'package:cl_server/src/inference/mqtt_event_listener.dart';

/// Test configuration for image embedding workflow tests
class ImageEmbeddingTestConfig {
  final String authBaseUrl;
  final String mediaStoreBaseUrl;
  final String inferenceBaseUrl;
  final String mqttBrokerHost;
  final int mqttBrokerPort;
  final Duration pollInterval;
  final Duration maxPollDuration;
  final Duration mqttTimeout;
  final bool useMqtt;

  // Test artifact configuration
  final String? testDir;
  final String? testName;

  ImageEmbeddingTestConfig({
    this.authBaseUrl = 'http://localhost:8000',
    this.mediaStoreBaseUrl = 'http://localhost:8001',
    this.inferenceBaseUrl = 'http://localhost:8002',
    this.mqttBrokerHost = 'localhost',
    this.mqttBrokerPort = 1883,
    this.pollInterval = const Duration(seconds: 2),
    this.maxPollDuration = const Duration(seconds: 120),
    this.mqttTimeout = const Duration(seconds: 30),
    this.useMqtt = false,
    this.testDir,
    this.testName,
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

  /// Wait for job completion by polling (legacy method)
  Future<Job?> waitForJobCompletion(
    String jobId, {
    Duration? pollInterval,
    Duration? maxDuration,
  }) async {
    return waitForJobCompletionAdvanced(
      jobId,
      useMqtt: false,
      usePolling: true,
      pollInterval: pollInterval,
      maxDuration: maxDuration,
    );
  }

  /// Wait for job completion with advanced options (MQTT, polling, or hybrid)
  Future<Job?> waitForJobCompletionAdvanced(
    String jobId, {
    bool useMqtt = false,
    bool usePolling = true,
    Duration? mqttTimeout,
    Duration? pollInterval,
    Duration? maxDuration,
  }) async {
    pollInterval ??= config.pollInterval;
    maxDuration ??= config.maxPollDuration;
    mqttTimeout ??= config.mqttTimeout;

    final startTime = DateTime.now();

    // If MQTT is enabled, try it first
    if (useMqtt) {
      try {
        final job = await _waitForJobCompletionViaMqtt(
          jobId,
          timeout: mqttTimeout,
        );
        if (job != null) {
          return job;
        }
      } catch (e) {
        // MQTT failed - log and continue to polling if enabled
        print('Warning: MQTT job completion failed for $jobId: $e');
        if (!usePolling) {
          return null;
        }
      }
    }

    // Fall back to polling if MQTT disabled or failed
    if (usePolling) {
      while (true) {
        try {
          final job = await inferenceClient.getJob(jobId);

          if (job.status == 'completed' || job.status == 'error') {
            return job;
          }

          final elapsed = DateTime.now().difference(startTime);
          if (elapsed > maxDuration!) {
            return null;
          }

          await Future.delayed(pollInterval!);
        } catch (e) {
          final elapsed = DateTime.now().difference(startTime);
          if (elapsed > maxDuration!) {
            return null;
          }
          await Future.delayed(pollInterval!);
        }
      }
    }

    // Neither MQTT nor polling enabled
    return null;
  }

  /// Wait for job completion via MQTT events
  Future<Job?> _waitForJobCompletionViaMqtt(
    String jobId, {
    required Duration timeout,
  }) async {
    try {
      late Job completedJob;
      late Completer<Job?> completer;

      final listener = MqttEventListener(
        brokerAddress: config.mqttBrokerHost,
        port: config.mqttBrokerPort,
        clientId:
            'dart_test_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
        connectionTimeout: timeout,
      );

      try {
        completer = Completer<Job?>();

        // Set up timeout
        final timeoutTimer = Timer(timeout, () {
          listener.disconnect().catchError((_) {});
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        });

        // Connect and listen
        await listener.connect((event) {
          if (event.jobId == jobId) {
            if (event.event == 'completed' || event.event == 'error') {
              timeoutTimer.cancel();
              listener.disconnect().catchError((_) {});
              if (!completer.isCompleted) {
                completer.complete(inferenceClient.getJob(jobId));
              }
            }
          }
        });

        return await completer.future;
      } finally {
        listener.disconnect().catchError((_) {});
      }
    } catch (e) {
      rethrow;
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

  // Artifact tracking
  Directory? artifactDir;
  File? jobsFile;
  File? mediaFile;

  ImageEmbeddingTestContext(this.helper) {
    // Initialize artifacts immediately
    _initializeArtifactsSync();
  }

  /// Synchronously initialize artifact directory
  void _initializeArtifactsSync() {
    final testDirStr = Platform.environment['CL_SERVER_TESTDIR'];
    if (testDirStr == null || testDirStr.isEmpty) {
      return;
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = Random().nextInt(100000);
      final artifactPath =
          '$testDirStr/dart_clients/cl_server/test_${timestamp}_$random';

      artifactDir = Directory(artifactPath);
      artifactDir!.createSync(recursive: true);

      jobsFile = File('$artifactPath/jobs.txt');
      mediaFile = File('$artifactPath/media.txt');
    } catch (e) {
      // Silently fail if can't initialize artifacts
    }
  }

  /// Initialize artifact directory for test
  Future<void> initializeArtifacts(String testName) async {
    final testDirStr = Platform.environment['CL_SERVER_TESTDIR'];
    if (testDirStr == null || testDirStr.isEmpty) {
      print('Warning: CL_SERVER_TESTDIR not set, skipping artifact logging');
      return;
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final artifactPath =
          '$testDirStr/dart_clients/cl_server/${testName}_$timestamp';

      artifactDir = Directory(artifactPath);
      await artifactDir!.create(recursive: true);

      jobsFile = File('$artifactPath/jobs.txt');
      mediaFile = File('$artifactPath/media.txt');

      print('Created artifact directory: $artifactPath');
    } catch (e) {
      print('Warning: Failed to initialize artifacts: $e');
    }
  }

  /// Register uploaded media for cleanup
  void registerMedia(String mediaStoreId) {
    uploadedMedia[DateTime.now().millisecondsSinceEpoch.toString()] =
        mediaStoreId;

    // Log to file
    _logMediaId(mediaStoreId);
  }

  /// Register created job for cleanup
  void registerJob(String jobId) {
    createdJobs.add(jobId);

    // Log to file
    _logJobId(jobId);
  }

  /// Log job ID to artifact file
  void _logJobId(String jobId) {
    if (jobsFile != null) {
      try {
        jobsFile!.writeAsStringSync('$jobId\n', mode: FileMode.append);
      } catch (e) {
        print('Warning: Failed to log job ID: $e');
      }
    }
  }

  /// Log media ID to artifact file
  void _logMediaId(String mediaId) {
    if (mediaFile != null) {
      try {
        mediaFile!.writeAsStringSync('$mediaId\n', mode: FileMode.append);
      } catch (e) {
        print('Warning: Failed to log media ID: $e');
      }
    }
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
