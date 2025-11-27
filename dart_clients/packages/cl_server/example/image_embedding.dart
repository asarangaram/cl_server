import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cl_server/cl_server.dart';
import 'package:mqtt5_client/mqtt5_client.dart';
import 'package:mqtt5_client/mqtt5_server_client.dart';

/// Image Embedding CLI Example Application
///
/// Demonstrates the complete image embedding workflow:
/// 1. Authenticate with provided credentials
/// 2. Upload image to media_store
/// 3. Submit embedding job to inference service
/// 4. Monitor job completion via MQTT (with polling fallback)
/// 5. Display embedding results
///
/// Usage:
/// dart example/image_embedding.dart \
///   --username admin \
///   --password password \
///   --image /path/to/image.jpg \
///   [--skip-mqtt] \
///   [--poll-interval 2] \
///   [--mqtt-timeout 30] \
///   [--poll-timeout 120] \
///   [--auth-host localhost] \
///   [--auth-port 8000] \
///   [--media-host localhost] \
///   [--media-port 8000] \
///   [--inference-host localhost] \
///   [--inference-port 8001]

void main(List<String> args) async {
  print('\n╔════════════════════════════════════════════════════════════════╗');
  print('║     Image Embedding Workflow - Dart Client Example            ║');
  print('╚════════════════════════════════════════════════════════════════╝\n');

  try {
    // Parse command line arguments
    final username = _getArgValue(args, '--username');
    final password = _getArgValue(args, '--password');
    final imagePath = _getArgValue(args, '--image');
    final noMqtt = args.contains('--no-mqtt') || args.contains('--skip-mqtt');
    final noPolling = args.contains('--no-polling');
    final pollInterval =
        int.tryParse(_getArgValue(args, '--poll-interval') ?? '2') ?? 2;
    final mqttTimeout =
        int.tryParse(_getArgValue(args, '--mqtt-timeout') ?? '30') ?? 30;
    final pollTimeout =
        int.tryParse(_getArgValue(args, '--poll-timeout') ?? '120') ?? 120;

    // Validate configuration
    if (noMqtt && noPolling) {
      print('❌ Error: Cannot disable both MQTT and polling');
      print('   Use either --no-mqtt (polling only) or --no-polling (MQTT only), not both');
      exit(1);
    }

    // Service URLs
    final authHost = _getArgValue(args, '--auth-host') ?? 'localhost';
    final authPort = _getArgValue(args, '--auth-port') ?? '8000';
    final mediaHost = _getArgValue(args, '--media-host') ?? 'localhost';
    final mediaPort = _getArgValue(args, '--media-port') ?? '8001';
    final inferenceHost =
        _getArgValue(args, '--inference-host') ?? 'localhost';
    final inferencePort =
        _getArgValue(args, '--inference-port') ?? '8002';

    // Validate required arguments
    if (username == null || password == null || imagePath == null) {
      _printUsage();
      exit(1);
    }

    // Validate image file exists
    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      print('❌ Error: Image file not found: $imagePath');
      exit(1);
    }

    // Initialize clients
    final authClient = AuthClient(baseUrl: 'http://$authHost:$authPort');
    final mediaStoreClient =
        MediaStoreClient(baseUrl: 'http://$mediaHost:$mediaPort');
    final inferenceClient =
        InferenceClient(baseUrl: 'http://$inferenceHost:$inferencePort');

    print('📋 Configuration:');
    print('   Username: $username');
    print('   Image: $imagePath');
    print('   MQTT Enabled: ${!noMqtt}');
    print('   Polling Enabled: ${!noPolling}');
    if (!noMqtt && !noPolling) {
      print('   Mode: MQTT + Polling (hybrid with fallback)');
      print('   MQTT Timeout: ${mqttTimeout}s');
      print('   Poll Interval: ${pollInterval}s (fallback)');
    } else if (!noMqtt) {
      print('   Mode: MQTT only (no fallback)');
      print('   MQTT Timeout: ${mqttTimeout}s');
    } else {
      print('   Mode: Polling only');
      print('   Poll Interval: ${pollInterval}s');
    }
    print('   Poll Timeout: ${pollTimeout}s');
    print('   Auth Service: http://$authHost:$authPort');
    print('   Media Store: http://$mediaHost:$mediaPort');
    print('   Inference Service: http://$inferenceHost:$inferencePort\n');

    // Step 1: Authenticate
    print('🔐 Step 1: Authenticating...');
    final token = await authClient.login(username, password);
    final tokenData = authClient.parseToken(token.accessToken);
    print('✅ Authentication successful!');
    print('   User ID: ${tokenData.userId}');
    print('   Permissions: ${tokenData.permissions.join(', ')}\n');

    // Step 2: Create collection for organizing media
    print('📂 Step 2: Creating collection...');
    final collection = await mediaStoreClient.createCollection(
      token: token.accessToken,
      label: 'Embedding Collection - ${DateTime.now()}',
      description: 'Collection for image embedding workflow',
    );
    final collectionId = collection.id;
    print('✅ Collection created!');
    print('   Collection ID: $collectionId\n');

    // Step 3: Upload image to media store
    print('📤 Step 3: Uploading image to media store...');
    final entity = await mediaStoreClient.createEntity(
      token: token.accessToken,
      file: File(imagePath),
      label: 'Image for embedding - ${DateTime.now()}',
      parentId: collectionId,
    );
    final mediaStoreId = entity.id.toString();
    print('✅ Image uploaded successfully!');
    print('   Media Store ID: $mediaStoreId');
    print('   File Path: ${entity.filePath}\n');

    // Step 4: Submit embedding job
    print('🤖 Step 4: Submitting image embedding job...');
    final job = await inferenceClient.createJob(
      token: token.accessToken,
      mediaStoreId: mediaStoreId,
      taskType: 'image_embedding',
      priority: 5,
    );
    print('✅ Job created successfully!');
    print('   Job ID: ${job.jobId}');
    print('   Status: ${job.status}');
    print('   Priority: ${job.priority}\n');

    // Step 5: Monitor job completion
    print('⏳ Step 5: Monitoring job completion...');
    print('   (Waiting for job to complete...)\n');

    final completionResult = await _waitForJobCompletion(
      inferenceClient: inferenceClient,
      jobId: job.jobId,
      useMqtt: !noMqtt,
      usePolling: !noPolling,
      mqttTimeout: Duration(seconds: mqttTimeout),
      pollInterval: Duration(seconds: pollInterval),
      pollTimeout: Duration(seconds: pollTimeout),
      brokerAddress: mediaHost, // MQTT broker on same host as services
      brokerPort: 1883,
    );

    if (completionResult == null) {
      print('❌ Job monitoring timeout or error');
      exit(1);
    }

    // Step 6: Display results
    print('📊 Step 6: Job Completion Results');
    print('   Status: ${completionResult.status}');
    if (completionResult.errorMessage != null) {
      print('   Error: ${completionResult.errorMessage}');
    } else {
      print('   ✅ Job completed successfully!');

      if (completionResult.result != null) {
        final result = completionResult.result!;
        print('   \n   Embedding Details:');
        print('      Dimension: ${result['embedding_dimension']}');
        print('      Stored in Vector DB: ${result['stored_in_vector_db']}');
        print('      Collection: ${result['collection']}');
        print('      Point ID: ${result['point_id']}');
      }
    }

    print('   Created: ${DateTime.fromMillisecondsSinceEpoch(completionResult.createdAt).toLocal()}');
    if (completionResult.startedAt != null) {
      print('   Started: ${DateTime.fromMillisecondsSinceEpoch(completionResult.startedAt!).toLocal()}');
    }
    if (completionResult.completedAt != null) {
      print('   Completed: ${DateTime.fromMillisecondsSinceEpoch(completionResult.completedAt!).toLocal()}');
    }

    print('\n✨ Image embedding workflow completed successfully!\n');
  } catch (e) {
    print('❌ Error: ${e.toString()}\n');
    if (e is ValidationException) {
      print('   Validation error: ${e.message}');
      if (e.responseBody != null) {
        print('   Details: ${e.responseBody}');
      }
    } else if (e is AuthenticationException) {
      print('   Authentication failed. Please check your username and password.');
    } else if (e is AuthorizationException) {
      print('   Authorization failed. You may not have permission for this operation.');
    } else if (e is NotFoundException) {
      print('   Resource not found.');
    }
    exit(1);
  }
}

/// Wait for job completion using configurable MQTT + polling approach
///
/// Strategy depends on flags:
/// - Both enabled (default): Try MQTT first, fallback to polling
/// - MQTT only: Use MQTT only, no fallback
/// - Polling only: Use polling only
///
Future<Job?> _waitForJobCompletion({
  required InferenceClient inferenceClient,
  required String jobId,
  required bool useMqtt,
  required bool usePolling,
  required Duration mqttTimeout,
  required Duration pollInterval,
  required Duration pollTimeout,
  required String brokerAddress,
  required int brokerPort,
}) async {
  // If only polling is enabled
  if (!useMqtt && usePolling) {
    return _pollJobCompletion(
      inferenceClient: inferenceClient,
      jobId: jobId,
      pollInterval: pollInterval,
      maxDuration: pollTimeout,
    );
  }

  // If only MQTT is enabled (no fallback)
  if (useMqtt && !usePolling) {
    try {
      final result = await _waitForMqttCompletion(
        jobId: jobId,
        timeout: mqttTimeout,
        brokerAddress: brokerAddress,
        brokerPort: brokerPort,
      );

      if (result != null) {
        print('✅ Job completion detected via MQTT');
        return await inferenceClient.getJob(jobId);
      } else {
        print('❌ MQTT timeout and polling fallback disabled');
        return null;
      }
    } catch (e) {
      print('❌ MQTT error and polling fallback disabled: $e');
      return null;
    }
  }

  // Default: Try MQTT first, fall back to polling if enabled
  try {
    final result = await _waitForMqttCompletion(
      jobId: jobId,
      timeout: mqttTimeout,
      brokerAddress: brokerAddress,
      brokerPort: brokerPort,
    );

    if (result != null) {
      print('✅ Job completion detected via MQTT');
      // Get final status from server
      return await inferenceClient.getJob(jobId);
    }
  } catch (e) {
    print('⚠️  MQTT listener error: $e');
    print('   Falling back to polling...');
  }

  // Fall back to polling
  print('   Using status polling as fallback...');
  return _pollJobCompletion(
    inferenceClient: inferenceClient,
    jobId: jobId,
    pollInterval: pollInterval,
    maxDuration: pollTimeout,
  );
}

/// Wait for job completion via MQTT
///
/// Subscribes to MQTT broker and waits for job completion message
/// Returns true if completion message received, false if timeout
Future<bool?> _waitForMqttCompletion({
  required String jobId,
  required Duration timeout,
  required String brokerAddress,
  required int brokerPort,
}) async {
  print('   📡 Connecting to MQTT broker at $brokerAddress:$brokerPort...');

  MqttServerClient? client;
  try {
    // Create MQTT client
    client = MqttServerClient.withPort(brokerAddress, 'image_embedding_${DateTime.now().millisecondsSinceEpoch}', brokerPort);

    // Set up callbacks
    client.onConnected = () {
      print('   ✅ Connected to MQTT broker');
    };

    client.onDisconnected = () {
      print('   ⚠️  Disconnected from MQTT broker');
    };

    // Connect to broker
    await client.connect();

    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      print('   ❌ Failed to connect to MQTT broker');
      return null;
    }

    // Subscribe to inference events topic
    const topic = 'inference/events';
    print('   📡 Subscribing to topic: $topic');
    client.subscribe(topic, MqttQos.atLeastOnce);

    // Create completer for completion
    final completer = Completer<bool>();

    // Listen for messages
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (final message in messages) {
        final payload = message.payload as MqttPublishMessage;
        final messageBytes = payload.payload.message;
        if (messageBytes == null) continue;
        final payloadStr = String.fromCharCodes(messageBytes.toList());

        try {
          final json = jsonDecode(payloadStr) as Map<String, dynamic>;
          final eventType = json['event'] as String?;
          final data = json['data'] as Map<String, dynamic>?;

          // Check if this is job completion event for our job
          if (eventType == 'job_completed' && data != null && data['job_id'] == jobId) {
            print('   ✅ Received job_completed event via MQTT');
            if (!completer.isCompleted) {
              completer.complete(true);
            }
          }
        } catch (e) {
          // Ignore parse errors
        }
      }
    });

    // Set timeout
    final timeoutFuture = Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        print('   ⏱️  MQTT listener timeout after ${timeout.inSeconds}s');
        completer.complete(false);
      }
    });

    // Wait for either completion or timeout
    final result = await Future.any([completer.future, timeoutFuture]);
    return result;

  } catch (e) {
    print('   ⚠️  MQTT error: $e');
    return null;
  } finally {
    // Clean up
    if (client != null && client.connectionStatus?.state == MqttConnectionState.connected) {
      client.disconnect();
    }
  }
}

/// Poll job status until completion or timeout
///
/// Periodically queries job status until job reaches terminal state
/// (completed or error) or timeout expires
Future<Job?> _pollJobCompletion({
  required InferenceClient inferenceClient,
  required String jobId,
  required Duration pollInterval,
  required Duration maxDuration,
}) async {
  final startTime = DateTime.now();

  while (true) {
    try {
      final job = await inferenceClient.getJob(jobId);
      final elapsed = DateTime.now().difference(startTime);

      if (job.status == 'completed' || job.status == 'error') {
        if (job.status == 'completed') {
          print(
              '✅ Job completed after ${elapsed.inSeconds} seconds (via polling)');
        } else {
          print('❌ Job failed after ${elapsed.inSeconds} seconds');
        }
        return job;
      }

      if (elapsed > maxDuration) {
        print(
            '❌ Job polling timeout after ${elapsed.inSeconds} seconds (status: ${job.status})');
        return null;
      }

      final nextCheck = elapsed + pollInterval;
      if (nextCheck <= maxDuration) {
        await Future.delayed(pollInterval);
      } else {
        return null;
      }
    } catch (e) {
      print('⚠️  Error polling job status: $e');
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed > maxDuration) {
        return null;
      }
      await Future.delayed(pollInterval);
    }
  }
}

/// Parse argument value from command line arguments
///
/// Looks for --key value pattern and returns value if found
String? _getArgValue(List<String> args, String key) {
  final index = args.indexOf(key);
  if (index != -1 && index + 1 < args.length) {
    return args[index + 1];
  }
  return null;
}

/// Print usage information
void _printUsage() {
  print('''
❌ Missing required arguments

Usage:
  dart example/image_embedding.dart \\
    --username <username> \\
    --password <password> \\
    --image <image_path> \\
    [--skip-mqtt] \\
    [--poll-interval <seconds>] \\
    [--mqtt-timeout <seconds>] \\
    [--poll-timeout <seconds>] \\
    [--auth-host <host>] \\
    [--auth-port <port>] \\
    [--media-host <host>] \\
    [--media-port <port>] \\
    [--inference-host <host>] \\
    [--inference-port <port>]

Required Arguments:
  --username        Username for authentication
  --password        Password for authentication
  --image           Path to image file for embedding

Optional Arguments:
  --skip-mqtt       Use polling only, skip MQTT listener
  --poll-interval   Polling interval in seconds (default: 2)
  --mqtt-timeout    MQTT listener timeout in seconds (default: 30)
  --poll-timeout    Maximum polling duration in seconds (default: 120)
  --auth-host       Authentication service host (default: localhost)
  --auth-port       Authentication service port (default: 8000)
  --media-host      Media store service host (default: localhost)
  --media-port      Media store service port (default: 8000)
  --inference-host  Inference service host (default: localhost)
  --inference-port  Inference service port (default: 8001)

Example:
  dart example/image_embedding.dart \\
    --username admin \\
    --password password \\
    --image /path/to/image.jpg

  dart example/image_embedding.dart \\
    --username admin \\
    --password password \\
    --image /path/to/image.jpg \\
    --skip-mqtt \\
    --poll-interval 2

''');
}
