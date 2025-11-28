# CL Server - Dart Client Library

A comprehensive Dart client library for interacting with CL Server microservices, including authentication, media store, and inference services.

## Features

- ✅ **Authentication Service Client** - Full support for user login, management, and permission handling
- ✅ **Media Store Service Client** - Entity management, file uploads, versioning, and metadata
- ✅ **Inference Service Client** - AI inference jobs (image embedding, face detection, face embedding)
- ✅ **Real-time Notifications** - MQTT event listener for job completion notifications
- 📦 **Type-Safe Models** - Strongly-typed Dart models for all API responses
- 🔒 **JWT Token Parsing** - Decode and validate JWT tokens without external dependencies
- 🌐 **RESTful API** - Clean, intuitive API for all endpoints
- 📡 **Event Streaming** - Real-time MQTT support for inference job completion
- 📝 **Comprehensive Tests** - Full integration test suite with real API calls
- 💻 **CLI Example** - Interactive command-line tool demonstrating all features
- 📚 **Well Documented** - Detailed examples and inline documentation

## Installation

Add `cl_server` to your `pubspec.yaml`:

```yaml
dependencies:
  cl_server: ^0.1.0
```

Or use the local path (during development):

```yaml
dependencies:
  cl_server:
    path: ../packages/cl_server
```

Then run:

```bash
dart pub get
```

## Quick Start

### Basic Authentication Example

```dart
import 'package:cl_server/cl_server.dart';

void main() async {
  final client = AuthClient(baseUrl: 'http://localhost:8000');

  try {
    // Login
    final token = await client.login('admin', 'admin');
    print('Token: ${token.accessToken}');

    // Get current user
    final user = await client.getCurrentUser(token.accessToken);
    print('User: ${user.username}');

    // Parse token to extract claims
    final tokenData = client.parseToken(token.accessToken);
    print('User ID: ${tokenData.userId}');
    print('Permissions: ${tokenData.permissions}');
    print('Is Admin: ${tokenData.isAdmin}');

    // Check if token is expired
    if (tokenData.isExpired) {
      print('Token has expired!');
    } else {
      print('Token expires in: ${tokenData.remainingDuration.inMinutes} minutes');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
```

## Common Usage Patterns

### Authentication

```dart
// Login
final token = await client.login('username', 'password');

// Get current user
final user = await client.getCurrentUser(token.accessToken);

// Create user (admin only)
final newUser = await client.createUser(
  token: adminToken,
  username: 'newuser',
  password: 'secure_password',
  permissions: ['read', 'write'],
);

// List users (admin only)
final users = await client.listUsers(token: adminToken);
```

### Media Store

```dart
// Create a collection
final collection = await mediaClient.createCollection(
  token: token.accessToken,
  label: 'My Photos',
  description: 'Family photos',
);

// Upload a file
final imageFile = File('photo.jpg');
final entity = await mediaClient.createEntity(
  token: token.accessToken,
  label: 'Vacation Photo',
  file: imageFile,
  parentId: collection.id,
);

// List entities
final result = await mediaClient.listEntities(
  token: token.accessToken,
  page: 1,
  pageSize: 20,
);
```

### Inference Service

```dart
// Create an inference job
final job = await inferenceClient.createJob(
  token: token.accessToken,
  mediaStoreId: 'image_uuid',
  taskType: 'image_embedding',
  priority: 5,
);

// Check job status
final updatedJob = await inferenceClient.getJob(job.jobId);
if (updatedJob.status == 'completed') {
  print('Results: ${updatedJob.result}');
}

// Monitor with MQTT
final listener = MqttEventListener(
  brokerAddress: 'localhost',
  port: 1883,
);

await listener.connect((event) {
  print('Job ${event.jobId} completed!');
  print('Data: ${event.data}');
});
```

## Error Handling

The library provides specific exception types for different error scenarios:

```dart
try {
  await client.login('username', 'wrongpassword');
} on AuthenticationException catch (e) {
  print('Login failed: ${e.message}');
} on ValidationException catch (e) {
  print('Validation error: ${e.message}');
} on NotFoundException catch (e) {
  print('Resource not found: ${e.message}');
} on ServerException catch (e) {
  print('Server error (${e.statusCode}): ${e.message}');
} on CLServerException catch (e) {
  print('Error: ${e.message}');
}
```

## Token Management

```dart
// Parse token to check permissions
final tokenData = client.parseToken(token.accessToken);

if (tokenData.hasPermission('ai_inference_support')) {
  // User can create inference jobs
}

if (tokenData.isExpired) {
  print('Token expired, please login again');
}

// Save/load tokens (application responsibility)
import 'dart:io';

// Save token
final file = File('token.txt');
await file.writeAsString(token.accessToken);

// Load token
final savedToken = await file.readAsString();
final user = await client.getCurrentUser(savedToken);
```

## Supported Inference Tasks

- **image_embedding** - Generate 512-dimensional CLIP embeddings for images
- **face_detection** - Detect faces in images with bounding boxes and landmarks
- **face_embedding** - Generate embeddings for detected faces

## Example CLI Application

Run the interactive CLI example:

```bash
cd example
dart run cli_app.dart --host localhost --port 8000
```

Available commands:
- `login <username> <password>` - Login
- `whoami` - Show current user
- `logout` - Clear session
- `token-info` - Display token details
- `users list` - List all users
- `users create <name> <password>` - Create user
- And more...

## Testing

Run integration tests against a live authentication service:

```bash
# Start the authentication service first
python services/authentication/main.py

# Then run tests
dart test test/integration/

# Run specific test file
dart test test/integration/auth_login_test.dart
```

## Documentation

- **[API Reference](doc/API.md)** - Complete API documentation for all services
- **[INTERNALS.md](INTERNALS.md)** - Architecture and design decisions
- **[QUICK_START.md](QUICK_START.md)** - 5-minute quick start guide
- **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - Technical implementation details

## Dependencies

### Required
- `http: ^1.1.0` - HTTP client
- `crypto: ^3.0.0` - Cryptographic operations
- `dart_jsonwebtoken: ^2.10.0` - JWT parsing

### Optional
- `mqtt5_client: ^4.0.0` - MQTT client for real-time event notifications (inference service only)

### Development only
- `test: ^1.25.0` - Test framework
- `lints: ^2.1.0` - Lint rules

## Service URLs

Default local development URLs:

| Service | Port | URL |
|---------|------|-----|
| Authentication | 8002 | http://localhost:8002 |
| Media Store | 8000 | http://localhost:8000 |
| Inference | 8001 | http://localhost:8001 |
| MQTT Broker | 1883 | localhost:1883 |

## Roadmap

- Phase 1 ✅ - Authentication Service - Complete
- Phase 2 ✅ - Media Store Service - Complete
- Phase 3 ✅ - Inference Service - Complete
- Token refresh support
- Signature verification (ES256)
- WebSocket support as alternative to MQTT
- Streaming file uploads

## Contributing

Contributions are welcome! Please follow the existing code style and add tests for new features.

## License

MIT License - See LICENSE file for details
