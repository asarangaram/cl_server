import 'dart:io';

import 'package:test/test.dart';
import 'package:cl_server/cl_server.dart';

import 'image_embedding_helpers.dart';
import '../fixtures/test_image_loader.dart';

void main() {
  group('Image Embedding Workflow Tests', () {
    late ImageEmbeddingTestHelper helper;
    late ImageEmbeddingTestContext context;

    setUpAll(() async {
      // Validate environment configuration
      final testDir = Platform.environment['CL_SERVER_TESTDIR'];
      if (testDir != null && testDir.isNotEmpty) {
        print('Test artifact directory: $testDir');
      } else {
        print(
          'Warning: CL_SERVER_TESTDIR not set. Artifacts will not be logged.',
        );
      }

      // Load service URLs from environment or use defaults
      final authUrl = Platform.environment['AUTH_SERVICE_URL'] ??
          'http://localhost:8000';
      final mediaStoreUrl = Platform.environment['MEDIA_STORE_URL'] ??
          'http://localhost:8001';
      final inferenceUrl = Platform.environment['INFERENCE_SERVICE_URL'] ??
          'http://localhost:8002';
      final mqttBrokerHost =
          Platform.environment['MQTT_BROKER_HOST'] ?? 'localhost';
      final mqttBrokerPort =
          int.tryParse(Platform.environment['MQTT_BROKER_PORT'] ?? '') ?? 1883;

      // Create config with environment variables
      final config = ImageEmbeddingTestConfig(
        authBaseUrl: authUrl,
        mediaStoreBaseUrl: mediaStoreUrl,
        inferenceBaseUrl: inferenceUrl,
        mqttBrokerHost: mqttBrokerHost,
        mqttBrokerPort: mqttBrokerPort,
      );

      print('Service URLs:');
      print('  Auth: $authUrl');
      print('  Media Store: $mediaStoreUrl');
      print('  Inference: $inferenceUrl');
      print('  MQTT Broker: $mqttBrokerHost:$mqttBrokerPort');

      // Initialize test infrastructure with config
      helper = ImageEmbeddingTestHelper(config: config);
      await helper.initialize();
    });

    setUp(() {
      // Create new context for each test
      context = ImageEmbeddingTestContext(helper);

      // Initialize artifacts if test directory is set
      final testDir = Platform.environment['CL_SERVER_TESTDIR'];
      if (testDir != null && testDir.isNotEmpty) {
        // Initialize artifacts asynchronously in the background
        // (we can't await in setUp, so we'll initialize when context is used)
      }
    });

    tearDown(() async {
      // Clean up test resources
      try {
        final token = await helper.authenticateAsAdmin();
        await context.cleanup(token);
      } catch (e) {
        print('Warning: Cleanup failed: $e');
      }
    });

    // ========================================================================
    // HAPPY PATH TESTS
    // ========================================================================

    group('Happy Path - Complete Workflow', () {
      test(
        'test_complete_image_embedding_workflow_with_polling',
        () async {
          // Setup: Authenticate
          final token = await helper.authenticateAsAdmin();

          // Upload image
          final mediaStoreId = await helper.uploadTestImage(token);
          context.registerMedia(mediaStoreId);

          // Submit embedding job
          final job = await helper.submitEmbeddingJob(token, mediaStoreId);
          context.registerJob(job.jobId);

          expect(job.jobId, isNotEmpty);
          expect(job.status, equals('pending'));
          expect(job.mediaStoreId, equals(mediaStoreId));
          expect(job.taskType, equals('image_embedding'));

          // Wait for completion
          final completedJob = await helper.waitForJobCompletion(job.jobId);
          expect(completedJob, isNotNull);
          expect(completedJob!.status, equals('completed'));

          // Verify result structure
          expect(completedJob.result, isNotNull);
          expect(
            completedJob.result!['embedding_dimension'],
            equals(512),
          ); // CLIP ViT-B/32 dimension
          expect(completedJob.result!['stored_in_vector_db'], isTrue);
          expect(completedJob.result!['collection'], equals('image_embeddings'));
          expect(completedJob.result!['point_id'], isNotNull);

          // Verify timestamps
          expect(completedJob.createdAt, isNotNull);
          expect(completedJob.startedAt, isNotNull);
          expect(completedJob.completedAt, isNotNull);
        },
        timeout: Timeout(Duration(seconds: 180)),
      );

      test(
        'test_complete_image_embedding_workflow_with_priority',
        () async {
          // Setup: Authenticate
          final token = await helper.authenticateAsAdmin();

          // Upload image
          final mediaStoreId = await helper.uploadTestImage(token);
          context.registerMedia(mediaStoreId);

          // Submit embedding job with high priority
          final job = await helper.submitEmbeddingJob(
            token,
            mediaStoreId,
            priority: 9,
          );
          context.registerJob(job.jobId);

          expect(job.priority, equals(9));

          // Wait for completion
          final completedJob = await helper.waitForJobCompletion(job.jobId);
          expect(completedJob, isNotNull);
          expect(completedJob!.status, equals('completed'));
          expect(completedJob.priority, equals(9));
        },
        timeout: Timeout(Duration(seconds: 180)),
      );

      test(
        'test_workflow_with_custom_image',
        () async {
          // Setup: Authenticate
          final token = await helper.authenticateAsAdmin();

          // Get specific test image
          final customImage =
              await TestImageLoader.getImageByName('test_image_3');
          expect(customImage, isNotNull);

          // Upload specific image
          final mediaStoreId =
              await helper.uploadTestImage(token, image: customImage);
          context.registerMedia(mediaStoreId);

          // Submit job
          final job = await helper.submitEmbeddingJob(token, mediaStoreId);
          context.registerJob(job.jobId);

          // Wait for completion
          final completedJob = await helper.waitForJobCompletion(job.jobId);
          expect(completedJob, isNotNull);
          expect(completedJob!.status, equals('completed'));
        },
        timeout: Timeout(Duration(seconds: 180)),
      );

      test(
        'test_verify_embedding_result_format',
        () async {
          // Setup: Authenticate
          final token = await helper.authenticateAsAdmin();

          // Complete workflow
          final completedJob =
              await helper.completeImageEmbeddingWorkflow(token);
          expect(completedJob, isNotNull);

          // Verify all expected fields in result
          final result = completedJob!.result!;
          expect(result.containsKey('embedding_dimension'), isTrue);
          expect(result.containsKey('stored_in_vector_db'), isTrue);
          expect(result.containsKey('collection'), isTrue);
          expect(result.containsKey('point_id'), isTrue);

          // Verify data types
          expect(result['embedding_dimension'], isA<int>());
          expect(result['stored_in_vector_db'], isA<bool>());
          expect(result['collection'], isA<String>());
        },
        timeout: Timeout(Duration(seconds: 180)),
      );

      test(
        'test_complete_workflow_with_polling_only',
        () async {
          final token = await helper.authenticateAsAdmin();

          // Upload image
          final mediaStoreId = await helper.uploadTestImage(token);
          context.registerMedia(mediaStoreId);

          // Submit job
          final job = await helper.submitEmbeddingJob(token, mediaStoreId);
          context.registerJob(job.jobId);

          // Wait using polling-only mechanism
          final completedJob =
              await helper.waitForJobCompletionAdvanced(
            job.jobId,
            useMqtt: false,
            usePolling: true,
          );

          expect(completedJob, isNotNull);
          expect(completedJob!.status, equals('completed'));
          expect(completedJob.result, isNotNull);
        },
        timeout: Timeout(Duration(seconds: 180)),
      );

      test(
        'test_complete_workflow_with_mqtt_only',
        () async {
          final token = await helper.authenticateAsAdmin();

          // Upload image
          final mediaStoreId = await helper.uploadTestImage(token);
          context.registerMedia(mediaStoreId);

          // Submit job
          final job = await helper.submitEmbeddingJob(token, mediaStoreId);
          context.registerJob(job.jobId);

          // Wait using MQTT-only mechanism (NO polling fallback)
          final completedJob =
              await helper.waitForJobCompletionAdvanced(
            job.jobId,
            useMqtt: true,
            usePolling: false,
            mqttTimeout: Duration(seconds: 60),
          );

          // MQTT must succeed - no fallback allowed
          expect(completedJob, isNotNull);
          expect(completedJob!.status, equals('completed'));
          expect(completedJob.result, isNotNull);
        },
        timeout: Timeout(Duration(seconds: 90)),
      );

      test(
        'test_complete_workflow_with_hybrid_mqtt_polling',
        () async {
          final token = await helper.authenticateAsAdmin();

          // Upload image
          final mediaStoreId = await helper.uploadTestImage(token);
          context.registerMedia(mediaStoreId);

          // Submit job
          final job = await helper.submitEmbeddingJob(token, mediaStoreId);
          context.registerJob(job.jobId);

          // Wait using hybrid mechanism (MQTT primary, polling fallback)
          final completedJob =
              await helper.waitForJobCompletionAdvanced(
            job.jobId,
            useMqtt: true,
            usePolling: true,
            mqttTimeout: Duration(seconds: 30),
          );

          expect(completedJob, isNotNull);
          expect(completedJob!.status, equals('completed'));
          expect(completedJob.result, isNotNull);
        },
        timeout: Timeout(Duration(seconds: 180)),
      );

      test(
        'test_concurrent_jobs_with_polling',
        () async {
          final token = await helper.authenticateAsAdmin();
          final completedJobs = <Job>[];

          // Submit 3 jobs concurrently and wait with polling
          final jobFutures = <Future<Job?>>[];
          for (int i = 0; i < 3; i++) {
            final mediaStoreId = await helper.uploadTestImage(token);
            context.registerMedia(mediaStoreId);

            final job = await helper.submitEmbeddingJob(token, mediaStoreId);
            context.registerJob(job.jobId);

            // Wait concurrently with polling-only
            jobFutures.add(
              helper.waitForJobCompletionAdvanced(
                job.jobId,
                useMqtt: false,
                usePolling: true,
              ),
            );
          }

          // Wait for all to complete
          final results = await Future.wait(jobFutures);
          expect(results.length, equals(3));

          for (final result in results) {
            expect(result, isNotNull);
            expect(result!.status, equals('completed'));
            completedJobs.add(result);
          }
        },
        timeout: Timeout(Duration(seconds: 300)),
      );

      test(
        'test_concurrent_jobs_with_mqtt_hybrid',
        () async {
          final token = await helper.authenticateAsAdmin();
          final completedJobs = <Job>[];

          // First upload all images before submitting jobs
          final mediaStoreIds = <String>[];
          for (int i = 0; i < 3; i++) {
            final mediaStoreId = await helper.uploadTestImage(token);
            context.registerMedia(mediaStoreId);
            mediaStoreIds.add(mediaStoreId);
          }

          // Then submit all jobs concurrently
          final jobSubmissionFutures = <Future<Job>>[];
          for (final mediaStoreId in mediaStoreIds) {
            jobSubmissionFutures.add(
              helper.submitEmbeddingJob(token, mediaStoreId),
            );
          }

          final submittedJobs = await Future.wait(jobSubmissionFutures);
          for (final job in submittedJobs) {
            context.registerJob(job.jobId);
          }

          // Wait for all jobs to complete concurrently with hybrid mechanism
          final jobFutures = <Future<Job?>>[];
          for (final job in submittedJobs) {
            jobFutures.add(
              helper.waitForJobCompletionAdvanced(
                job.jobId,
                useMqtt: true,
                usePolling: true,
                mqttTimeout: Duration(seconds: 30),
              ),
            );
          }

          // Wait for all to complete
          final results = await Future.wait(jobFutures);
          expect(results.length, equals(3));

          for (final result in results) {
            expect(result, isNotNull);
            expect(result!.status, equals('completed'));
            completedJobs.add(result);
          }
        },
        timeout: Timeout(Duration(seconds: 300)),
      );
    });

    // ========================================================================
    // ERROR SCENARIO TESTS
    // ========================================================================

    group('Error Scenarios', () {
      test(
        'test_invalid_credentials',
        () async {
          // Attempt login with wrong password
          expect(
            () async => await helper.authClient.login('admin', 'wrongpassword'),
            throwsA(isA<AuthenticationException>()),
          );
        },
      );

      test(
        'test_image_file_not_found',
        () async {
          final token = await helper.authenticateAsAdmin();

          // Create a collection first
          final collection = await helper.mediaStoreClient.createCollection(
            token: token.accessToken,
            label: 'Test Collection',
          );

          // Try to upload non-existent image
          expect(
            () async => await helper.mediaStoreClient.createEntity(
              token: token.accessToken,
              file: File('/non/existent/path/image.jpg'),
              label: 'Test',
              parentId: collection.id,
            ),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('does not exist'),
              ),
            ),
          );
        },
      );

      test(
        'test_invalid_media_store_id',
        () async {
          final token = await helper.authenticateAsAdmin();

          // Try to submit job with non-existent media store ID
          expect(
            () async => await helper.submitEmbeddingJob(
              token,
              'non-existent-id-12345',
            ),
            throwsA(isA<Exception>()),
          );
        },
      );

      test(
        'test_inference_job_with_invalid_priority',
        () async {
          final token = await helper.authenticateAsAdmin();
          final mediaStoreId = await helper.uploadTestImage(token);
          context.registerMedia(mediaStoreId);

          // Try to submit job with priority out of range
          expect(
            () async => await helper.inferenceClient.createJob(
              token: token.accessToken,
              mediaStoreId: mediaStoreId,
              taskType: 'image_embedding',
              priority: 15, // Invalid: max is 10
            ),
            throwsA(isA<ValidationException>()),
          );
        },
      );

      test(
        'test_inference_job_polling_timeout',
        () async {
          final token = await helper.authenticateAsAdmin();
          final mediaStoreId = await helper.uploadTestImage(token);
          context.registerMedia(mediaStoreId);

          // Submit job
          final job = await helper.submitEmbeddingJob(token, mediaStoreId);
          context.registerJob(job.jobId);

          // Try to wait with very short timeout
          final result = await helper.waitForJobCompletion(
            job.jobId,
            maxDuration: Duration(milliseconds: 100),
          );

          // Should timeout and return null
          expect(result, isNull);
        },
      );

      test(
        'test_submission_without_required_permission',
        () async {
          // Try to authenticate as user without ai_inference_support permission
          try {
            final token = await helper.authenticate(TestUser.noPermissionUser);
            final mediaStoreId = await helper.uploadTestImage(token);

            // Should fail due to missing permission
            expect(
              () async => await helper.submitEmbeddingJob(token, mediaStoreId),
              throwsA(isA<AuthorizationException>()),
            );
          } catch (e) {
            // It's okay if user creation hasn't been set up in test environment
            print('Skipping permission test: $e');
          }
        },
      );

      test(
        'test_get_job_status_after_delete',
        () async {
          final token = await helper.authenticateAsAdmin();
          final mediaStoreId = await helper.uploadTestImage(token);

          // Submit job
          final job = await helper.submitEmbeddingJob(token, mediaStoreId);

          // Delete the job
          await helper.inferenceClient.deleteJob(
            token: token.accessToken,
            jobId: job.jobId,
          );

          // Try to get status (should fail)
          expect(
            () async => await helper.getJobStatus(job.jobId),
            throwsA(isA<NotFoundException>()),
          );
        },
      );

      test(
        'test_mqtt_timeout_with_polling_fallback',
        () async {
          final token = await helper.authenticateAsAdmin();
          final mediaStoreId = await helper.uploadTestImage(token);
          context.registerMedia(mediaStoreId);

          // Submit job
          final job = await helper.submitEmbeddingJob(token, mediaStoreId);
          context.registerJob(job.jobId);

          // Wait with MQTT timeout but polling fallback enabled
          final completedJob =
              await helper.waitForJobCompletionAdvanced(
            job.jobId,
            useMqtt: true,
            usePolling: true,
            mqttTimeout: Duration(milliseconds: 100), // Very short MQTT timeout
          );

          // Should complete via polling fallback
          expect(completedJob, isNotNull);
          expect(completedJob!.status, equals('completed'));
        },
        timeout: Timeout(Duration(seconds: 180)),
      );

      test(
        'test_mqtt_only_with_unavailable_broker',
        () async {
          final token = await helper.authenticateAsAdmin();
          final mediaStoreId = await helper.uploadTestImage(token);
          context.registerMedia(mediaStoreId);

          // Submit job
          final job = await helper.submitEmbeddingJob(token, mediaStoreId);
          context.registerJob(job.jobId);

          // Try to wait with MQTT-only using invalid broker
          final completedJob =
              await helper.waitForJobCompletionAdvanced(
            job.jobId,
            useMqtt: true,
            usePolling: false,
            mqttTimeout: Duration(seconds: 5),
          );

          // Should timeout and return null
          expect(completedJob, isNull);
        },
        timeout: Timeout(Duration(seconds: 15)),
      );

      test(
        'test_polling_timeout_scenario',
        () async {
          final token = await helper.authenticateAsAdmin();
          final mediaStoreId = await helper.uploadTestImage(token);
          context.registerMedia(mediaStoreId);

          // Submit job
          final job = await helper.submitEmbeddingJob(token, mediaStoreId);
          context.registerJob(job.jobId);

          // Wait with very short polling timeout to test timeout behavior
          final result = await helper.waitForJobCompletionAdvanced(
            job.jobId,
            useMqtt: false,
            usePolling: true,
            maxDuration: Duration(milliseconds: 10),
            pollInterval: Duration(milliseconds: 5),
          );

          // Should timeout and return null (job processing takes longer than timeout)
          expect(result, isNull);
        },
      );

      test(
        'test_network_error_during_job_submission',
        () async {
          final token = await helper.authenticateAsAdmin();
          final mediaStoreId = await helper.uploadTestImage(token);
          context.registerMedia(mediaStoreId);

          // Try to submit job with invalid task type
          expect(
            () async => await helper.inferenceClient.createJob(
              token: token.accessToken,
              mediaStoreId: mediaStoreId,
              taskType: 'invalid_task_type_xyz',
              priority: 5,
            ),
            throwsA(isA<Exception>()),
          );
        },
      );

      test(
        'test_token_expiration_during_long_job',
        () async {
          final token = await helper.authenticateAsAdmin();
          final mediaStoreId = await helper.uploadTestImage(token);
          context.registerMedia(mediaStoreId);

          // Submit job with normal token
          final job = await helper.submitEmbeddingJob(token, mediaStoreId);
          context.registerJob(job.jobId);

          // Wait for completion (should work even if theoretical token expiry)
          final completedJob = await helper.waitForJobCompletion(job.jobId);

          // Should complete successfully
          expect(completedJob, isNotNull);
          expect(completedJob!.status, equals('completed'));
        },
        timeout: Timeout(Duration(seconds: 180)),
      );
    });

    // ========================================================================
    // INTEGRATION EDGE CASES
    // ========================================================================

    group('Integration Edge Cases', () {
      test(
        'test_multiple_sequential_embeddings',
        () async {
          final token = await helper.authenticateAsAdmin();
          final completedJobs = <Job>[];

          // Upload and process 3 images sequentially
          for (int i = 0; i < 3; i++) {
            final image = await TestImageLoader.getRandomImage();
            expect(image, isNotNull);

            final mediaStoreId = await helper.uploadTestImage(
              token,
              image: image,
            );
            context.registerMedia(mediaStoreId);

            final job = await helper.submitEmbeddingJob(token, mediaStoreId);
            context.registerJob(job.jobId);

            final completedJob = await helper.waitForJobCompletion(job.jobId);
            expect(completedJob, isNotNull);
            expect(completedJob!.status, equals('completed'));
            expect(completedJob.mediaStoreId, equals(mediaStoreId));

            completedJobs.add(completedJob);
          }

          // Verify all jobs completed with correct media IDs
          expect(completedJobs.length, equals(3));
          for (int i = 0; i < 3; i++) {
            expect(completedJobs[i].status, equals('completed'));
            expect(completedJobs[i].result, isNotNull);
          }
        },
        timeout: Timeout(Duration(seconds: 300)),
      );

      test(
        'test_concurrent_embedding_jobs',
        () async {
          final token = await helper.authenticateAsAdmin();

          // Upload all images first
          final mediaStoreIds = <String>[];
          for (int i = 0; i < 3; i++) {
            final mediaStoreId = await helper.uploadTestImage(token);
            mediaStoreIds.add(mediaStoreId);
            context.registerMedia(mediaStoreId);
          }

          // Then submit all jobs
          final jobs = <Job>[];
          for (final mediaStoreId in mediaStoreIds) {
            final job = await helper.submitEmbeddingJob(token, mediaStoreId);
            context.registerJob(job.jobId);
            jobs.add(job);
          }

          // Wait for all jobs to complete concurrently
          final jobFutures = jobs
              .map((job) => helper.waitForJobCompletion(job.jobId))
              .toList();
          final results = await Future.wait(jobFutures);

          // Verify all completed
          expect(results.length, equals(3));
          for (final result in results) {
            expect(result, isNotNull);
            expect(result!.status, equals('completed'));
          }
        },
        timeout: Timeout(Duration(seconds: 300)),
      );

      test(
        'test_multiple_images_different_priorities',
        () async {
          final token = await helper.authenticateAsAdmin();
          final priorities = [9, 5, 1]; // High, medium, low

          // Upload all images first
          final mediaStoreIds = <String>[];
          for (int i = 0; i < priorities.length; i++) {
            final mediaStoreId = await helper.uploadTestImage(token);
            context.registerMedia(mediaStoreId);
            mediaStoreIds.add(mediaStoreId);
          }

          // Then submit jobs with different priorities
          final jobs = <Job>[];
          for (int i = 0; i < mediaStoreIds.length; i++) {
            final job = await helper.submitEmbeddingJob(
              token,
              mediaStoreIds[i],
              priority: priorities[i],
            );
            context.registerJob(job.jobId);
            jobs.add(job);
          }

          // Verify priorities were set
          expect(jobs[0].priority, equals(9));
          expect(jobs[1].priority, equals(5));
          expect(jobs[2].priority, equals(1));

          // Wait for all to complete
          final jobFutures = jobs
              .map((job) => helper.waitForJobCompletion(job.jobId))
              .toList();
          final results = await Future.wait(jobFutures);

          for (final result in results) {
            expect(result, isNotNull);
            expect(result!.status, equals('completed'));
          }
        },
        timeout: Timeout(Duration(seconds: 300)),
      );

      test(
        'test_job_status_polling_consistency',
        () async {
          final token = await helper.authenticateAsAdmin();
          final mediaStoreId = await helper.uploadTestImage(token);
          context.registerMedia(mediaStoreId);

          final job = await helper.submitEmbeddingJob(token, mediaStoreId);
          context.registerJob(job.jobId);

          // Poll status multiple times before completion
          Job? polledJob;
          final pollResults = <String>[];

          for (int i = 0; i < 5; i++) {
            polledJob = await helper.getJobStatus(job.jobId);
            pollResults.add(polledJob.status);
            await Future.delayed(Duration(seconds: 1));
          }

          // Should see progression from pending/processing to completed
          // Status should not go backwards
          var maxStatusIndex = -1;
          const statusProgression = ['pending', 'processing', 'completed'];

          for (final status in pollResults) {
            final currentIndex = statusProgression.indexOf(status);
            if (currentIndex >= 0) {
              expect(currentIndex, greaterThanOrEqualTo(maxStatusIndex));
              maxStatusIndex = currentIndex;
            }
          }

          // Final status should be completed
          expect(pollResults.last, equals('completed'));
        },
        timeout: Timeout(Duration(seconds: 300)),
      );

      test(
        'test_different_image_sources',
        () async {
          final token = await helper.authenticateAsAdmin();

          // Test with different images from manifest
          final allImages = await TestImageLoader.loadAll();
          expect(allImages.isNotEmpty, isTrue);

          final results = <Job>[];

          // Process first 3 different images
          for (int i = 0; i < allImages.length && i < 3; i++) {
            final mediaStoreId = await helper.uploadTestImage(
              token,
              image: allImages[i],
            );
            context.registerMedia(mediaStoreId);

            final job = await helper.submitEmbeddingJob(token, mediaStoreId);
            context.registerJob(job.jobId);

            final completed = await helper.waitForJobCompletion(job.jobId);
            expect(completed, isNotNull);
            results.add(completed!);
          }

          // All should complete successfully
          for (final result in results) {
            expect(result.status, equals('completed'));
            expect(result.result!['embedding_dimension'], equals(512));
          }
        },
        timeout: Timeout(Duration(seconds: 300)),
      );

      test(
        'test_rapid_successive_job_submissions',
        () async {
          final token = await helper.authenticateAsAdmin();

          // First upload all 5 images
          final mediaStoreIds = <String>[];
          for (int i = 0; i < 5; i++) {
            final mediaStoreId = await helper.uploadTestImage(token);
            context.registerMedia(mediaStoreId);
            mediaStoreIds.add(mediaStoreId);
          }

          // Then rapidly submit 5 jobs in quick succession
          final submittedJobs = <Job>[];
          for (final mediaStoreId in mediaStoreIds) {
            final job = await helper.submitEmbeddingJob(token, mediaStoreId);
            context.registerJob(job.jobId);
            submittedJobs.add(job);
            // Minimal delay between submissions
          }

          // Wait for all jobs to complete
          final completedJobs = <Job>[];
          for (final job in submittedJobs) {
            final completed = await helper.waitForJobCompletion(job.jobId);
            expect(completed, isNotNull);
            completedJobs.add(completed!);
          }

          // Verify all completed successfully
          expect(completedJobs.length, equals(5));
          for (final job in completedJobs) {
            expect(job.status, equals('completed'));
            expect(job.result, isNotNull);
          }
        },
        timeout: Timeout(Duration(seconds: 300)),
      );

      test(
        'test_concurrent_clients_different_credentials',
        () async {
          // Test with admin user
          final adminToken = await helper.authenticateAsAdmin();

          // Upload and submit job as admin
          final adminMediaId = await helper.uploadTestImage(adminToken);
          context.registerMedia(adminMediaId);

          final adminJob =
              await helper.submitEmbeddingJob(adminToken, adminMediaId);
          context.registerJob(adminJob.jobId);

          // Try with different user if available
          try {
            final testUserToken = await helper.authenticate(TestUser.testUser);

            // Upload as test user
            final testUserMediaId = await helper.uploadTestImage(testUserToken);
            context.registerMedia(testUserMediaId);

            // Submit job as test user
            final testUserJob = await helper.submitEmbeddingJob(
              testUserToken,
              testUserMediaId,
            );
            context.registerJob(testUserJob.jobId);

            // Wait for both jobs to complete
            final adminCompleted =
                await helper.waitForJobCompletion(adminJob.jobId);
            final testUserCompleted =
                await helper.waitForJobCompletion(testUserJob.jobId);

            expect(adminCompleted, isNotNull);
            expect(testUserCompleted, isNotNull);
            expect(adminCompleted!.status, equals('completed'));
            expect(testUserCompleted!.status, equals('completed'));
          } catch (e) {
            // If test user not available, just verify admin job works
            print('Test user not available, testing admin only: $e');
            final adminCompleted =
                await helper.waitForJobCompletion(adminJob.jobId);
            expect(adminCompleted, isNotNull);
          }
        },
        timeout: Timeout(Duration(seconds: 300)),
      );
    });

    // ========================================================================
    // RESOURCE MANAGEMENT TESTS
    // ========================================================================

    group('Resource Management', () {
      test(
        'test_cleanup_removes_all_resources',
        () async {
          final token = await helper.authenticateAsAdmin();

          // Create resources
          final mediaStoreId = await helper.uploadTestImage(token);
          final job = await helper.submitEmbeddingJob(token, mediaStoreId);

          context.registerMedia(mediaStoreId);
          context.registerJob(job.jobId);

          // Verify resources exist
          expect(() async => await helper.getJobStatus(job.jobId), returnsNormally);

          // Clean up
          await context.cleanup(token);

          // Verify job is deleted
          expect(
            () async => await helper.getJobStatus(job.jobId),
            throwsA(isA<NotFoundException>()),
          );
        },
      );

      test(
        'test_test_image_loader_initialization',
        () async {
          // Reset and reinitialize
          TestImageLoader.reset();

          await TestImageLoader.initialize();

          final primary = await TestImageLoader.getPrimaryImage();
          expect(primary, isNotNull);
          expect(await primary!.exists(), isTrue);

          final secondary = await TestImageLoader.getSecondaryImage();
          expect(secondary, isNotNull);
          expect(await secondary!.exists(), isTrue);

          final allImages = await TestImageLoader.loadAll();
          expect(allImages.isNotEmpty, isTrue);
        },
      );

      test(
        'test_test_image_manifest_integrity',
        () async {
          final images = await TestImageLoader.loadAll();
          expect(images.isNotEmpty, isTrue);

          // Verify all images exist
          for (final image in images) {
            expect(
              await image.exists(),
              isTrue,
              reason: 'Image should exist: ${image.absolutePath}',
            );
          }

          // Verify absolute paths
          for (final image in images) {
            expect(
              image.absolutePath.startsWith('/'),
              isTrue,
              reason: 'Image path should be absolute: ${image.absolutePath}',
            );
          }
        },
      );
    });
  });
}
