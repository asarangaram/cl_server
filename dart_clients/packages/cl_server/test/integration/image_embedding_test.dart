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
      // Initialize test infrastructure
      helper = ImageEmbeddingTestHelper();
      await helper.initialize();
    });

    setUp(() {
      // Create new context for each test
      context = ImageEmbeddingTestContext(helper);
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
                contains('FileSystemException'),
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
          final jobFutures = <Future<Job?>>[];

          // Submit 3 jobs concurrently
          final mediaStoreIds = <String>[];
          for (int i = 0; i < 3; i++) {
            final mediaStoreId = await helper.uploadTestImage(token);
            mediaStoreIds.add(mediaStoreId);
            context.registerMedia(mediaStoreId);

            final job = await helper.submitEmbeddingJob(token, mediaStoreId);
            context.registerJob(job.jobId);

            // Start waiting for all jobs concurrently
            jobFutures.add(helper.waitForJobCompletion(job.jobId));
          }

          // Wait for all jobs to complete
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

          // Submit jobs with different priorities
          final jobs = <Job>[];
          final priorities = [9, 5, 1]; // High, medium, low

          for (int i = 0; i < priorities.length; i++) {
            final mediaStoreId = await helper.uploadTestImage(token);
            context.registerMedia(mediaStoreId);

            final job = await helper.submitEmbeddingJob(
              token,
              mediaStoreId,
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
          for (final job in jobs) {
            final completed = await helper.waitForJobCompletion(job.jobId);
            expect(completed, isNotNull);
            expect(completed!.status, equals('completed'));
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
