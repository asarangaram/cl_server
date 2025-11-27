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

## Authentication API

### Login

```dart
final token = await client.login('username', 'password');
// Returns: Token with accessToken and tokenType
```

### Get Current User

```dart
final user = await client.getCurrentUser(token.accessToken);
// Returns: User object with id, username, isAdmin, isActive, createdAt, permissions
```

### Manage Users (Admin Only)

```dart
// Create user
final newUser = await client.createUser(
  token: adminToken,
  username: 'newuser',
  password: 'secure_password',
  isAdmin: false,
  permissions: ['read', 'write'],
);

// List users
final users = await client.listUsers(
  token: adminToken,
  skip: 0,
  limit: 100,
);

// Get specific user
final user = await client.getUser(
  token: adminToken,
  userId: 5,
);

// Update user
final updated = await client.updateUser(
  token: adminToken,
  userId: 5,
  password: 'new_password',
  isAdmin: true,
  permissions: ['read', 'write', 'delete'],
);

// Delete user
await client.deleteUser(
  token: adminToken,
  userId: 5,
);
```

## Token Management

### Parse Token

```dart
final tokenData = client.parseToken(token.accessToken);
// Returns: TokenData with userId, permissions, isAdmin, expiresAt

print(tokenData.userId);        // User ID
print(tokenData.permissions);   // List of permission strings
print(tokenData.isAdmin);       // Boolean
print(tokenData.expiresAt);     // DateTime
print(tokenData.isExpired);     // Check if expired
print(tokenData.remainingDuration); // Duration until expiration
```

### Check Token Expiration

```dart
if (client.isTokenExpired(token.accessToken)) {
  print('Token has expired, please login again');
}
```

### Permission Checking

```dart
final tokenData = client.parseToken(token.accessToken);

if (tokenData.hasPermission('read')) {
  // User has read permission
}
```

### Save/Load Tokens (Stateless Design)

Since the library uses a stateless design, your application is responsible for token persistence:

```dart
import 'dart:io';

// Save token to file
final file = File('token.txt');
await file.writeAsString(token.accessToken);

// Load token from file
final savedToken = await file.readAsString();
final user = await client.getCurrentUser(savedToken);
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

## Inference Service API

### Create Inference Job

```dart
final inferenceClient = InferenceClient(baseUrl: 'http://localhost:8001');

try {
  // Create an image embedding job
  final job = await inferenceClient.createJob(
    token: token.accessToken,
    mediaStoreId: 'image_uuid',
    taskType: 'image_embedding',
    priority: 5,  // 0-10, higher is more urgent
  );

  print('Job created: ${job.jobId}');
  print('Status: ${job.status}');
} catch (e) {
  print('Error creating job: $e');
}
```

### Check Job Status

```dart
// Get job status (no token required - job_id acts as capability token)
final job = await inferenceClient.getJob(jobId);

print('Job Status: ${job.status}');
if (job.status == 'completed') {
  print('Results: ${job.result}');
} else if (job.status == 'error') {
  print('Error: ${job.errorMessage}');
}
```

### Delete Job

```dart
// Delete a job (requires ai_inference_support permission)
await inferenceClient.deleteJob(
  token: token.accessToken,
  jobId: jobId,
);
```

### Monitor Job Completion with MQTT

```dart
final listener = MqttEventListener(
  brokerAddress: 'localhost',
  port: 1883,
  clientId: 'dart_inference_${DateTime.now().millisecondsSinceEpoch}',
  connectionTimeout: Duration(seconds: 10),
);

try {
  // Connect and subscribe to job completion events
  await listener.connect((event) {
    print('Job ${event.jobId} event: ${event.event}');
    print('Data: ${event.data}');
    print('Timestamp: ${event.timestamp}');
  });

  // Listener is now active and will call the callback for each job completion

  // Later, disconnect when done
  await listener.disconnect();
} catch (e) {
  print('MQTT error: $e');
}
```

### Admin Operations

```dart
// Get service health
final health = await inferenceClient.healthCheck();
print('Status: ${health.status}');
print('Database: ${health.database}');
print('Queue Size: ${health.queueSize}');

// Get service statistics (admin only)
final stats = await inferenceClient.getStats(token: adminToken);
print('Pending jobs: ${stats.jobs['pending']}');
print('Completed jobs: ${stats.jobs['completed']}');

// Cleanup old jobs (admin only)
final cleanup = await inferenceClient.cleanup(
  token: adminToken,
  olderThanSeconds: 86400,  // 1 day
  status: 'completed',
  removeResults: true,
);
print('Deleted: ${cleanup.jobsDeleted} jobs');
```

## Inference Service Supported Task Types

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
- `save-token <file>` - Save token to file
- `load-token <file>` - Load token from file
- `users list` - List all users
- `users get <id>` - Get user details
- `users create <name> <password>` - Create user
- `users update <id> [--admin] [--perms]` - Update user
- `users delete <id>` - Delete user
- `public-key` - Fetch public key

## Testing

Run integration tests against a live authentication service:

```bash
# Start the authentication service first
python services/authentication/main.py

# Then run tests
dart test test/integration/

# Run specific test file
dart test test/integration/auth_login_test.dart

# Watch mode
dart test --watch test/integration/
```

## Architecture

### Stateless Design

The `AuthClient` is intentionally stateless:
- No internal token storage
- Application passes token with each request
- Full control over token lifecycle
- No side effects or hidden state

Example pattern:
```dart
// 1. Get token
final token = await client.login(username, password);

// 2. Store it (app responsibility)
localStorage.save('auth_token', token.accessToken);

// 3. Use it for requests
final user = await client.getCurrentUser(token.accessToken);

// 4. Check expiration when needed
if (client.isTokenExpired(token.accessToken)) {
  // Re-login
}
```

### No Signature Verification

The client parses JWT tokens but does NOT verify ES256 signatures. Instead:
- Tokens are decoded for claims inspection (userId, permissions, isAdmin, expiresAt)
- Server is trusted as the source of truth for token validity
- HTTPS is used for transport security
- Can be extended later if signature verification is needed

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

## Roadmap

- Phase 1 ✅ - Authentication Service - Complete with user management and permissions
- Phase 2 ✅ - Media Store Service - Complete with entity management, file uploads, versioning
- Phase 3 ✅ - Inference Service - Complete with job management, MQTT real-time notifications
- Support for signature verification (ES256)
- Support for token refresh
- Integration tests for inference service
- WebSocket support as alternative to MQTT

## Contributing

Contributions are welcome! Please follow the existing code style and add tests for new features.

## License

MIT License - See LICENSE file for details
