# Quick Start Guide - CL Server Dart Client

Get started with the CL Server Dart client library in minutes!

## Installation

### Add to pubspec.yaml

```yaml
dependencies:
  cl_server:
    path: ../packages/cl_server
```

Then run:
```bash
dart pub get
```

## 5-Minute Examples

### 1. Authentication

```dart
import 'package:cl_server/cl_server.dart';

void main() async {
  final authClient = AuthClient(baseUrl: 'http://localhost:8002');

  // Login
  final token = await authClient.login('admin', 'admin');
  print('Access Token: ${token.accessToken}');

  // Get current user
  final user = await authClient.getCurrentUser(token.accessToken);
  print('Logged in as: ${user.username}');

  authClient.close();
}
```

### 2. Create Media Store Entity

```dart
import 'package:cl_server/cl_server.dart';
import 'dart:io';

void main() async {
  final mediaStoreClient = MediaStoreClient(baseUrl: 'http://localhost:8000');
  final authClient = AuthClient(baseUrl: 'http://localhost:8002');

  // Login first
  final token = await authClient.login('admin', 'admin');

  // Create a collection
  final collection = await mediaStoreClient.createCollection(
    token: token.accessToken,
    label: 'My Collection',
    description: 'A test collection',
  );
  print('Created collection: ${collection.label}');

  // Upload a file
  final file = File('image.jpg');
  final entity = await mediaStoreClient.createEntity(
    token: token.accessToken,
    label: 'Test Image',
    file: file,
    parentId: collection.id,
  );
  print('Uploaded entity: ${entity.label}');

  mediaStoreClient.close();
  authClient.close();
}
```

### 3. Submit Inference Job

```dart
import 'package:cl_server/cl_server.dart';

void main() async {
  final inferenceClient = InferenceClient(baseUrl: 'http://localhost:8001');
  final authClient = AuthClient(baseUrl: 'http://localhost:8002');

  // Login
  final token = await authClient.login('admin', 'admin');

  // Create an image embedding job
  final job = await inferenceClient.createJob(
    token: token.accessToken,
    mediaStoreId: 'your-image-uuid',
    taskType: 'image_embedding',
    priority: 5,
  );
  print('Created job: ${job.jobId}');
  print('Status: ${job.status}');

  // Check job status
  await Future.delayed(Duration(seconds: 2));
  final updatedJob = await inferenceClient.getJob(job.jobId);
  print('Updated status: ${updatedJob.status}');

  if (updatedJob.status == 'completed') {
    print('Results: ${updatedJob.result}');
  }

  inferenceClient.close();
  authClient.close();
}
```

### 4. Monitor Job with MQTT

```dart
import 'package:cl_server/cl_server.dart';

void main() async {
  final listener = MqttEventListener(
    brokerAddress: 'localhost',
    port: 1883,
    clientId: 'dart_client_${DateTime.now().millisecondsSinceEpoch}',
  );

  try {
    // Listen for job completion events
    await listener.connect((event) {
      print('✓ Job ${event.jobId} completed!');
      print('  Event: ${event.event}');
      print('  Data: ${event.data}');
    });

    print('Listening for job completions... (Ctrl+C to stop)');

    // Keep the app running
    await Future.delayed(Duration(hours: 1));
  } finally {
    await listener.disconnect();
  }
}
```

### 5. Complete Workflow

```dart
import 'package:cl_server/cl_server.dart';
import 'dart:io';

void main() async {
  // Initialize clients
  final authClient = AuthClient(baseUrl: 'http://localhost:8002');
  final mediaStoreClient = MediaStoreClient(baseUrl: 'http://localhost:8000');
  final inferenceClient = InferenceClient(baseUrl: 'http://localhost:8001');
  final listener = MqttEventListener(
    brokerAddress: 'localhost',
    port: 1883,
    clientId: 'dart_workflow',
  );

  try {
    // Step 1: Authenticate
    print('1️⃣  Authenticating...');
    final token = await authClient.login('admin', 'admin');
    print('   ✓ Logged in as admin');

    // Step 2: Upload image
    print('2️⃣  Uploading image...');
    final imageFile = File('image.jpg');
    final entity = await mediaStoreClient.createEntity(
      token: token.accessToken,
      label: 'Analysis Image',
      file: imageFile,
    );
    print('   ✓ Uploaded: ${entity.label} (ID: ${entity.id})');

    // Step 3: Submit inference job
    print('3️⃣  Submitting inference job...');
    final job = await inferenceClient.createJob(
      token: token.accessToken,
      mediaStoreId: entity.id.toString(),
      taskType: 'face_detection',
      priority: 8,
    );
    print('   ✓ Job created: ${job.jobId}');

    // Step 4: Listen for completion
    print('4️⃣  Waiting for completion...');
    await listener.connect((event) {
      if (event.jobId == job.jobId) {
        print('   ✓ Job completed!');
        print('   Data: ${event.data}');
      }
    });

    // Step 5: Check results
    print('5️⃣  Retrieving results...');
    final completedJob = await inferenceClient.getJob(job.jobId);
    print('   ✓ Status: ${completedJob.status}');
    print('   Results: ${completedJob.result}');

  } catch (e) {
    print('❌ Error: $e');
  } finally {
    // Cleanup
    authClient.close();
    mediaStoreClient.close();
    inferenceClient.close();
    await listener.disconnect();
  }
}
```

## Common Patterns

### Error Handling

```dart
try {
  final token = await authClient.login('user', 'password');
} on AuthenticationException catch (e) {
  print('Login failed: ${e.message}');
} on CLServerException catch (e) {
  print('Server error: ${e.message}');
}
```

### Token Management

```dart
// Parse token to check permissions
final tokenData = authClient.parseToken(token.accessToken);

if (tokenData.hasPermission('ai_inference_support')) {
  // Can create inference jobs
  await inferenceClient.createJob(...);
}

if (tokenData.isExpired) {
  print('Token expired, please login again');
}
```

### Batch Operations

```dart
// Create multiple inference jobs
final mediaIds = ['uuid1', 'uuid2', 'uuid3'];

for (final mediaId in mediaIds) {
  final job = await inferenceClient.createJob(
    token: token.accessToken,
    mediaStoreId: mediaId,
    taskType: 'image_embedding',
  );
  print('Created job: ${job.jobId}');
}
```

## Service URLs

Default local development URLs:

| Service | Port | URL |
|---------|------|-----|
| Authentication | 8002 | http://localhost:8002 |
| Media Store | 8000 | http://localhost:8000 |
| Inference | 8001 | http://localhost:8001 |
| MQTT Broker | 1883 | localhost:1883 |

## Next Steps

- Read [README.md](README.md) for comprehensive API documentation
- Check [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) for architecture details
- Explore [example/](example/) directory for more examples
- Run tests: `dart test test/integration/`

## Troubleshooting

**Connection refused?**
- Ensure services are running: `python services/authentication/main.py`
- Check the service is listening on the correct port

**MQTT events not received?**
- Verify MQTT broker is running on port 1883
- Check that job is actually completing (use `getJob()`)
- Ensure callback function is properly defined

**Permission denied?**
- Verify user has required permissions
- Check token hasn't expired: `tokenData.isExpired`
- Use admin account for admin-only operations

## Support

For issues and questions, check:
- [GitHub Issues](https://github.com/anthropics/cl_server)
- Inline documentation in source files
- Example CLI application in `example/cli_app.dart`
