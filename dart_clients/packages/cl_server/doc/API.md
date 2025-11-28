# CL Server Dart Client - API Reference

Complete API reference for the CL Server Dart client library.

## Table of Contents

- [Authentication Service](#authentication-service)
- [Media Store Service](#media-store-service)
- [Inference Service](#inference-service)
- [Models](#models)
- [Error Handling](#error-handling)

---

## Authentication Service

The `AuthClient` provides methods for user authentication and management.

### Constructor

```dart
AuthClient({
  required String baseUrl,
  CLHttpClient? httpClient,
  Duration? requestTimeout,
})
```

**Parameters:**
- `baseUrl` - Base URL of the authentication service (e.g., `http://localhost:8002`)
- `httpClient` - Optional custom HTTP client
- `requestTimeout` - Request timeout duration (default: 30 seconds)

### Authentication Methods

#### login

```dart
Future<Token> login(String username, String password)
```

Authenticate with username and password.

**Parameters:**
- `username` - User's username
- `password` - User's password

**Returns:** `Token` object containing `accessToken` and `tokenType`

**Throws:**
- `AuthenticationException` - Invalid credentials
- `ValidationException` - Invalid request format
- `ServerException` - Server error

**Example:**
```dart
final client = AuthClient(baseUrl: 'http://localhost:8002');
final token = await client.login('admin', 'admin');
print('Access Token: ${token.accessToken}');
```

#### getCurrentUser

```dart
Future<User> getCurrentUser(String token)
```

Get the currently authenticated user's information.

**Parameters:**
- `token` - JWT access token

**Returns:** `User` object with user details

**Throws:**
- `AuthenticationException` - Invalid or expired token
- `ServerException` - Server error

**Example:**
```dart
final user = await client.getCurrentUser(token.accessToken);
print('Username: ${user.username}');
print('Is Admin: ${user.isAdmin}');
```

### User Management Methods (Admin Only)

#### createUser

```dart
Future<User> createUser({
  required String token,
  required String username,
  required String password,
  bool isAdmin = false,
  bool isActive = true,
  List<String> permissions = const [],
})
```

Create a new user. Requires admin privileges.

**Parameters:**
- `token` - Admin JWT token
- `username` - New user's username
- `password` - New user's password
- `isAdmin` - Whether user has admin privileges (default: false)
- `isActive` - Whether user account is active (default: true)
- `permissions` - List of permission strings

**Returns:** Created `User` object

**Throws:**
- `AuthenticationException` - Invalid token
- `AuthorizationException` - Not an admin
- `DuplicateResourceException` - Username already exists
- `ValidationException` - Invalid parameters

**Example:**
```dart
final newUser = await client.createUser(
  token: adminToken,
  username: 'john_doe',
  password: 'secure_password',
  permissions: ['read', 'write'],
);
```

#### listUsers

```dart
Future<List<User>> listUsers({
  required String token,
  int skip = 0,
  int limit = 100,
})
```

List all users with pagination. Requires admin privileges.

**Parameters:**
- `token` - Admin JWT token
- `skip` - Number of users to skip (default: 0)
- `limit` - Maximum number of users to return (default: 100)

**Returns:** List of `User` objects

**Example:**
```dart
final users = await client.listUsers(
  token: adminToken,
  skip: 0,
  limit: 50,
);
```

#### getUser

```dart
Future<User> getUser({
  required String token,
  required int userId,
})
```

Get a specific user by ID. Requires admin privileges.

**Parameters:**
- `token` - Admin JWT token
- `userId` - ID of the user to retrieve

**Returns:** `User` object

**Throws:**
- `NotFoundException` - User not found

#### updateUser

```dart
Future<User> updateUser({
  required String token,
  required int userId,
  String? password,
  bool? isAdmin,
  bool? isActive,
  List<String>? permissions,
})
```

Update a user's properties. Requires admin privileges.

**Parameters:**
- `token` - Admin JWT token
- `userId` - ID of the user to update
- `password` - New password (optional)
- `isAdmin` - Admin status (optional)
- `isActive` - Active status (optional)
- `permissions` - New permissions list (optional)

**Returns:** Updated `User` object

**Note:** At least one field must be provided for update.

#### deleteUser

```dart
Future<void> deleteUser({
  required String token,
  required int userId,
})
```

Delete a user. Requires admin privileges.

**Parameters:**
- `token` - Admin JWT token
- `userId` - ID of the user to delete

**Throws:**
- `NotFoundException` - User not found

### Token Utilities

#### parseToken

```dart
TokenData parseToken(String token)
```

Parse a JWT token to extract claims without verification.

**Parameters:**
- `token` - JWT access token

**Returns:** `TokenData` object with parsed claims

**Example:**
```dart
final tokenData = client.parseToken(token.accessToken);
print('User ID: ${tokenData.userId}');
print('Permissions: ${tokenData.permissions}');
print('Is Admin: ${tokenData.isAdmin}');
print('Expires At: ${tokenData.expiresAt}');
```

#### isTokenExpired

```dart
bool isTokenExpired(String token)
```

Check if a token has expired.

**Parameters:**
- `token` - JWT access token

**Returns:** `true` if expired, `false` otherwise

**Example:**
```dart
if (client.isTokenExpired(token.accessToken)) {
  print('Token expired, please login again');
}
```

#### tryParseToken

```dart
TokenData? tryParseToken(String token)
```

Attempt to parse a token, returning `null` if invalid.

**Parameters:**
- `token` - JWT access token

**Returns:** `TokenData` or `null` if parsing fails

### Public Key Methods

#### getPublicKey

```dart
Future<String> getPublicKey()
```

Retrieve the server's public key for token verification.

**Returns:** Public key in PEM format

#### clearPublicKeyCache

```dart
void clearPublicKeyCache()
```

Clear the cached public key, forcing a fresh retrieval on next request.

### Cleanup

#### close

```dart
void close()
```

Close the HTTP client and release resources.

---

## Media Store Service

The `MediaStoreClient` provides methods for managing media entities, files, and versioning.

### Constructor

```dart
MediaStoreClient({
  required String baseUrl,
  CLHttpClient? httpClient,
  Duration? requestTimeout,
})
```

**Parameters:**
- `baseUrl` - Base URL of the media store service (e.g., `http://localhost:8000`)
- `httpClient` - Optional custom HTTP client
- `requestTimeout` - Request timeout duration (default: 30 seconds)

### Entity Management

#### createCollection

```dart
Future<Entity> createCollection({
  required String token,
  required String label,
  String? description,
  int? parentId,
})
```

Create a new collection entity (folder-like container).

**Parameters:**
- `token` - JWT access token
- `label` - Collection name
- `description` - Optional description
- `parentId` - Optional parent collection ID

**Returns:** Created `Entity` object

**Example:**
```dart
final collection = await client.createCollection(
  token: token.accessToken,
  label: 'My Photos',
  description: 'Family photos from 2024',
);
```

#### createEntity

```dart
Future<Entity> createEntity({
  required String token,
  required String label,
  required File file,
  String? description,
  int? parentId,
})
```

Create a new file-based entity with file upload.

**Parameters:**
- `token` - JWT access token
- `label` - Entity name
- `file` - File to upload
- `description` - Optional description
- `parentId` - Optional parent collection ID

**Returns:** Created `Entity` object with file metadata

**Example:**
```dart
final imageFile = File('photo.jpg');
final entity = await client.createEntity(
  token: token.accessToken,
  label: 'Vacation Photo',
  file: imageFile,
  parentId: collection.id,
);
```

#### listEntities

```dart
Future<PaginatedEntities> listEntities({
  required String token,
  int? page,
  int? pageSize,
  int? version,
})
```

List entities with pagination.

**Parameters:**
- `token` - JWT access token
- `page` - Page number (optional)
- `pageSize` - Items per page (optional)
- `version` - Filter by version number (optional)

**Returns:** `PaginatedEntities` with items and pagination metadata

**Example:**
```dart
final result = await client.listEntities(
  token: token.accessToken,
  page: 1,
  pageSize: 20,
);
print('Total: ${result.total}');
for (var entity in result.items) {
  print('- ${entity.label}');
}
```

#### getEntity

```dart
Future<Entity> getEntity({
  required String token,
  required int entityId,
  int? version,
})
```

Get a specific entity by ID.

**Parameters:**
- `token` - JWT access token
- `entityId` - Entity ID
- `version` - Optional version number to retrieve

**Returns:** `Entity` object

**Throws:**
- `NotFoundException` - Entity not found

#### updateEntity

```dart
Future<Entity> updateEntity({
  required String token,
  required int entityId,
  required String label,
  required bool isCollection,
  String? description,
  int? parentId,
  File? file,
})
```

Perform a full update (PUT) of an entity.

**Parameters:**
- `token` - JWT access token
- `entityId` - Entity ID to update
- `label` - New label
- `isCollection` - Whether entity is a collection
- `description` - New description (optional)
- `parentId` - New parent ID (optional)
- `file` - New file to upload (optional)

**Returns:** Updated `Entity` object

**Note:** This replaces all fields. Use `patchEntity` for partial updates.

#### patchEntity

```dart
Future<Entity> patchEntity({
  required String token,
  required int entityId,
  String? label,
  String? description,
  int? parentId,
  File? file,
})
```

Perform a partial update (PATCH) of an entity.

**Parameters:**
- `token` - JWT access token
- `entityId` - Entity ID to update
- `label` - New label (optional)
- `description` - New description (optional)
- `parentId` - New parent ID (optional, use explicit null to remove parent)
- `file` - New file to upload (optional)

**Returns:** Updated `Entity` object

**Example:**
```dart
// Update only the label
final updated = await client.patchEntity(
  token: token.accessToken,
  entityId: entity.id,
  label: 'New Label',
);

// Remove parent (move to root)
final moved = await client.patchEntity(
  token: token.accessToken,
  entityId: entity.id,
  parentId: null,
);
```

#### deleteEntity

```dart
Future<void> deleteEntity({
  required String token,
  required int entityId,
})
```

Permanently delete an entity.

**Parameters:**
- `token` - JWT access token
- `entityId` - Entity ID to delete

#### softDeleteEntity

```dart
Future<Entity> softDeleteEntity({
  required String token,
  required int entityId,
})
```

Soft delete an entity (mark as deleted without removing).

**Parameters:**
- `token` - JWT access token
- `entityId` - Entity ID to soft delete

**Returns:** Updated `Entity` object with `isDeleted: true`

#### deleteAllEntities

```dart
Future<void> deleteAllEntities({
  required String token,
})
```

Delete all entities (hard delete). Use with caution!

**Parameters:**
- `token` - JWT access token

### Versioning

#### getVersions

```dart
Future<PaginatedEntities> getVersions({
  required String token,
  required int entityId,
  int? page,
  int? pageSize,
})
```

Get all versions of an entity.

**Parameters:**
- `token` - JWT access token
- `entityId` - Entity ID
- `page` - Page number (optional)
- `pageSize` - Items per page (optional)

**Returns:** `PaginatedEntities` with version history

**Example:**
```dart
final versions = await client.getVersions(
  token: token.accessToken,
  entityId: entity.id,
);
for (var version in versions.items) {
  print('Version ${version.version}: ${version.label}');
}
```

#### getVersion

```dart
Future<Entity> getVersion({
  required String token,
  required int entityId,
  required int versionNumber,
})
```

Get a specific version of an entity.

**Parameters:**
- `token` - JWT access token
- `entityId` - Entity ID
- `versionNumber` - Version number to retrieve

**Returns:** `Entity` object for that version

### Configuration

#### getConfig

```dart
Future<Config> getConfig({
  required String token,
})
```

Get current service configuration.

**Parameters:**
- `token` - JWT access token

**Returns:** `Config` object with service settings

#### setReadAuth

```dart
Future<Config> setReadAuth({
  required String token,
  required bool readAuthEnabled,
})
```

Update read authentication requirement.

**Parameters:**
- `token` - JWT access token
- `readAuthEnabled` - Whether to require authentication for read operations

**Returns:** Updated `Config` object

### Cleanup

#### close

```dart
void close()
```

Close the HTTP client and release resources.

---

## Inference Service

The `InferenceClient` provides methods for managing AI inference jobs.

### Constructor

```dart
InferenceClient({
  required String baseUrl,
  CLHttpClient? httpClient,
  Duration? requestTimeout,
})
```

**Parameters:**
- `baseUrl` - Base URL of the inference service (e.g., `http://localhost:8001`)
- `httpClient` - Optional custom HTTP client
- `requestTimeout` - Request timeout duration (default: 30 seconds)

### Job Management

#### createJob

```dart
Future<Job> createJob({
  required String token,
  required String mediaStoreId,
  required String taskType,
  int priority = 5,
})
```

Create a new inference job.

**Parameters:**
- `token` - JWT access token (requires `ai_inference_support` permission)
- `mediaStoreId` - ID of media entity to process
- `taskType` - Task type: `image_embedding`, `face_detection`, or `face_embedding`
- `priority` - Job priority 0-10, higher is more urgent (default: 5)

**Returns:** `Job` object with job details

**Throws:**
- `AuthenticationException` - Invalid token
- `AuthorizationException` - Missing `ai_inference_support` permission
- `ValidationException` - Invalid parameters
- `DuplicateResourceException` - Job already exists for this media + task combination

**Example:**
```dart
final job = await client.createJob(
  token: token.accessToken,
  mediaStoreId: 'uuid-of-image',
  taskType: 'image_embedding',
  priority: 8,
);
print('Job ID: ${job.jobId}');
print('Status: ${job.status}');
```

**Supported Task Types:**
- `image_embedding` - Generate 512-dimensional CLIP embeddings
- `face_detection` - Detect faces with bounding boxes and landmarks
- `face_embedding` - Generate embeddings for detected faces

#### getJob

```dart
Future<Job> getJob(String jobId)
```

Get the status and results of an inference job.

**Parameters:**
- `jobId` - Job ID to retrieve

**Returns:** `Job` object with current status and results

**Throws:**
- `NotFoundException` - Job not found

**Note:** This endpoint does not require authentication. The job ID acts as a capability token.

**Example:**
```dart
final job = await client.getJob(jobId);
if (job.status == 'completed') {
  print('Results: ${job.result}');
} else if (job.status == 'error') {
  print('Error: ${job.errorMessage}');
}
```

**Job Statuses:**
- `pending` - Waiting in queue
- `processing` - Currently being processed
- `completed` - Successfully completed
- `error` - Failed with error
- `sync_failed` - Completed but failed to sync results

#### deleteJob

```dart
Future<void> deleteJob({
  required String token,
  required String jobId,
})
```

Delete an inference job and associated data.

**Parameters:**
- `token` - JWT access token (requires `ai_inference_support` permission)
- `jobId` - Job ID to delete

**Throws:**
- `AuthenticationException` - Invalid token
- `AuthorizationException` - Missing permission
- `NotFoundException` - Job not found

### Monitoring

#### healthCheck

```dart
Future<HealthResponse> healthCheck()
```

Get service health status.

**Returns:** `HealthResponse` with service health information

**Note:** This endpoint does not require authentication.

**Example:**
```dart
final health = await client.healthCheck();
print('Status: ${health.status}');
print('Database: ${health.database}');
print('Worker: ${health.worker}');
print('Queue Size: ${health.queueSize}');
```

#### getStats

```dart
Future<StatsResponse> getStats({
  required String token,
})
```

Get service statistics. Requires admin privileges.

**Parameters:**
- `token` - Admin JWT token

**Returns:** `StatsResponse` with job counts and metrics

**Throws:**
- `AuthorizationException` - Not an admin

**Example:**
```dart
final stats = await client.getStats(token: adminToken);
print('Pending: ${stats.jobs['pending']}');
print('Completed: ${stats.jobs['completed']}');
print('Queue Size: ${stats.queueSize}');
```

### Admin Operations

#### cleanup

```dart
Future<CleanupResponse> cleanup({
  required String token,
  int? olderThanSeconds,
  String status = 'all',
  bool removeResults = true,
  bool removeQueue = true,
  bool removeOrphanedFiles = false,
})
```

Cleanup old jobs and files. Requires admin privileges.

**Parameters:**
- `token` - Admin JWT token
- `olderThanSeconds` - Only delete jobs older than this (optional)
- `status` - Filter by status: `all`, `completed`, `error`, `pending` (default: `all`)
- `removeResults` - Remove result files (default: true)
- `removeQueue` - Remove queue entries (default: true)
- `removeOrphanedFiles` - Remove orphaned files (default: false)

**Returns:** `CleanupResponse` with deletion counts

**Example:**
```dart
// Delete completed jobs older than 1 day
final cleanup = await client.cleanup(
  token: adminToken,
  olderThanSeconds: 86400,
  status: 'completed',
  removeResults: true,
);
print('Deleted ${cleanup.jobsDeleted} jobs');
print('Deleted ${cleanup.filesDeleted} files');
```

### Cleanup

#### close

```dart
void close()
```

Close the HTTP client and release resources.

---

## MQTT Event Listener

The `MqttEventListener` provides real-time notifications for job completion events.

### Constructor

```dart
MqttEventListener({
  required String brokerAddress,
  int port = 1883,
  String? clientId,
  Duration connectionTimeout = const Duration(seconds: 10),
})
```

**Parameters:**
- `brokerAddress` - MQTT broker address (e.g., `localhost`)
- `port` - MQTT broker port (default: 1883)
- `clientId` - Unique client identifier (optional, auto-generated if not provided)
- `connectionTimeout` - Connection timeout duration (default: 10 seconds)

### Methods

#### connect

```dart
Future<void> connect(void Function(MqttEvent event) onEvent)
```

Connect to MQTT broker and subscribe to job completion events.

**Parameters:**
- `onEvent` - Callback function invoked for each job completion event

**Throws:**
- Exception if connection fails

**Example:**
```dart
final listener = MqttEventListener(
  brokerAddress: 'localhost',
  port: 1883,
  clientId: 'dart_client_${DateTime.now().millisecondsSinceEpoch}',
);

await listener.connect((event) {
  print('Job ${event.jobId} completed!');
  print('Event: ${event.event}');
  print('Data: ${event.data}');
  print('Timestamp: ${event.timestamp}');
});
```

#### disconnect

```dart
Future<void> disconnect()
```

Disconnect from MQTT broker and cleanup resources.

**Example:**
```dart
await listener.disconnect();
```

#### isConnected

```dart
bool get isConnected
```

Check if currently connected to MQTT broker.

**Returns:** `true` if connected, `false` otherwise

---

## Models

### Core Models

#### Token

Represents an authentication token.

**Fields:**
- `accessToken: String` - JWT access token
- `tokenType: String` - Token type (usually "bearer")

#### TokenData

Parsed JWT token claims.

**Fields:**
- `userId: int` - User ID
- `permissions: List<String>` - List of permission strings
- `isAdmin: bool` - Whether user is an admin
- `expiresAt: DateTime` - Token expiration time
- `isExpired: bool` - Whether token has expired (computed)
- `remainingDuration: Duration` - Time until expiration (computed)

**Methods:**
- `hasPermission(String permission): bool` - Check if user has specific permission

#### User

Represents a user account.

**Fields:**
- `id: int` - User ID
- `username: String` - Username
- `isAdmin: bool` - Admin status
- `isActive: bool` - Account active status
- `createdAt: DateTime` - Account creation timestamp
- `permissions: List<String>` - List of permissions

#### Entity

Represents a media entity (file or collection).

**Fields:**
- `id: int` - Entity ID
- `label: String` - Entity name/label
- `description: String?` - Optional description
- `isCollection: bool` - Whether entity is a collection
- `isDeleted: bool` - Soft delete status
- `parentId: int?` - Parent collection ID
- `version: int` - Current version number
- `addedDate: int` - Creation timestamp (milliseconds)
- `updatedDate: int` - Last update timestamp (milliseconds)
- `ref: String?` - File reference/path
- `type: String?` - MIME type
- `itemCount: int?` - Number of items (for collections)
- `originalDate: int?` - Original file date (milliseconds)

#### PaginatedEntities

Paginated list of entities.

**Fields:**
- `items: List<Entity>` - List of entities
- `total: int` - Total number of entities
- `page: int?` - Current page number
- `pageSize: int?` - Items per page
- `pages: int?` - Total number of pages

#### Config

Service configuration.

**Fields:**
- `readAuthEnabled: bool` - Whether read operations require authentication

### Inference Models

#### Job

Represents an inference job.

**Fields:**
- `jobId: String` - Unique job identifier
- `taskType: String` - Task type (image_embedding, face_detection, face_embedding)
- `mediaStoreId: String` - Media entity ID
- `status: String` - Job status (pending, processing, completed, error, sync_failed)
- `priority: int` - Job priority (0-10)
- `createdAt: int` - Creation timestamp (milliseconds)
- `startedAt: int?` - Start timestamp (milliseconds)
- `completedAt: int?` - Completion timestamp (milliseconds)
- `errorMessage: String?` - Error details if failed
- `result: Map<String, dynamic>?` - Job results (polymorphic based on taskType)

#### ImageEmbeddingResult

Result for image embedding jobs.

**Fields:**
- `embeddingDimension: int?` - Embedding dimension (512 for CLIP)
- `storedInVectorDb: bool?` - Whether stored in vector database
- `collection: String?` - Vector DB collection name
- `pointId: int?` - Vector DB point ID

#### FaceDetectionResult

Result for face detection jobs.

**Fields:**
- `faces: List<Face>?` - List of detected faces
- `faceCount: int?` - Total number of faces detected

#### FaceEmbeddingResult

Result for face embedding jobs.

**Fields:**
- `faces: List<Face>?` - List of faces with embeddings
- `faceCount: int?` - Total number of faces
- `storedInVectorDb: bool?` - Whether stored in vector database
- `collection: String?` - Vector DB collection name

#### Face

Represents a detected face.

**Fields:**
- `faceIndex: int?` - Face index in detection results
- `bbox: BoundingBox?` - Bounding box coordinates
- `confidence: double?` - Detection confidence (0-1)
- `embeddingDimension: int?` - Embedding dimension
- `pointId: int?` - Vector DB point ID
- `landmarks: Map<String, dynamic>?` - Facial landmarks (eyes, nose, mouth)

#### BoundingBox

Face bounding box coordinates.

**Fields:**
- `x: double` - X coordinate
- `y: double` - Y coordinate
- `width: double` - Box width
- `height: double` - Box height

#### HealthResponse

Service health status.

**Fields:**
- `status: String` - Overall health status
- `database: String` - Database connectivity status
- `worker: String` - Background worker status
- `queueSize: int` - Current job queue size

#### StatsResponse

Service statistics.

**Fields:**
- `queueSize: int` - Current queue size
- `jobs: Map<String, int>` - Job counts by status
- `storage: Map<String, dynamic>` - Storage metrics

#### CleanupResponse

Cleanup operation results.

**Fields:**
- `jobsDeleted: int` - Number of jobs deleted
- `filesDeleted: int` - Number of files removed
- `queueEntriesRemoved: int` - Queue entries removed

#### MqttEvent

MQTT job completion event.

**Fields:**
- `jobId: String` - Job identifier
- `event: String` - Event type (e.g., "completed")
- `data: Map<String, dynamic>` - Event payload
- `timestamp: int` - Event timestamp (milliseconds)

---

## Error Handling

The library provides a hierarchy of exception classes for different error scenarios.

### Exception Hierarchy

```
CLServerException (base)
├── AuthenticationException (401)
├── AuthorizationException (403)
├── NotFoundException (404)
├── ValidationException (400)
├── DuplicateResourceException (409)
└── ServerException (5xx)
```

### Exception Classes

#### CLServerException

Base exception class for all CL Server errors.

**Fields:**
- `message: String` - Error message
- `statusCode: int?` - HTTP status code
- `responseBody: dynamic` - Raw response body

#### AuthenticationException

Thrown when authentication fails (HTTP 401).

**Common Causes:**
- Invalid credentials
- Missing token
- Expired token
- Malformed token

#### AuthorizationException

Thrown when authorization fails (HTTP 403).

**Common Causes:**
- Missing required permission
- Not an admin when admin required
- Insufficient privileges

#### NotFoundException

Thrown when a resource is not found (HTTP 404).

**Common Causes:**
- Invalid entity ID
- Invalid user ID
- Invalid job ID
- Deleted resource

#### ValidationException

Thrown when request validation fails (HTTP 400).

**Common Causes:**
- Invalid parameters
- Missing required fields
- Invalid field format
- Invalid task type

#### DuplicateResourceException

Thrown when a resource already exists (HTTP 409).

**Common Causes:**
- Duplicate username
- Duplicate job (same media + task type)

#### ServerException

Thrown for server errors (HTTP 5xx).

**Common Causes:**
- Database errors
- Internal server errors
- Service unavailable

### Error Handling Patterns

#### Basic Try-Catch

```dart
try {
  final token = await client.login('user', 'password');
} on AuthenticationException catch (e) {
  print('Login failed: ${e.message}');
} on CLServerException catch (e) {
  print('Error: ${e.message}');
}
```

#### Specific Error Handling

```dart
try {
  final user = await client.createUser(
    token: token,
    username: 'newuser',
    password: 'password',
  );
} on DuplicateResourceException catch (e) {
  print('Username already exists');
} on AuthorizationException catch (e) {
  print('You need admin privileges');
} on ValidationException catch (e) {
  print('Invalid input: ${e.message}');
} on CLServerException catch (e) {
  print('Unexpected error: ${e.message}');
}
```

#### Comprehensive Error Handling

```dart
try {
  final job = await inferenceClient.createJob(
    token: token.accessToken,
    mediaStoreId: mediaId,
    taskType: 'image_embedding',
  );
} on AuthenticationException catch (e) {
  // Token invalid or expired - re-login required
  print('Authentication failed: ${e.message}');
} on AuthorizationException catch (e) {
  // Missing ai_inference_support permission
  print('Missing permission: ${e.message}');
} on ValidationException catch (e) {
  // Invalid parameters
  print('Validation error: ${e.message}');
} on DuplicateResourceException catch (e) {
  // Job already exists
  print('Job already exists: ${e.message}');
} on NotFoundException catch (e) {
  // Media entity not found
  print('Media not found: ${e.message}');
} on ServerException catch (e) {
  // Server error
  print('Server error (${e.statusCode}): ${e.message}');
} on CLServerException catch (e) {
  // Catch-all for other errors
  print('Unexpected error: ${e.message}');
}
```

### Best Practices

1. **Always catch specific exceptions first**, then fall back to base `CLServerException`
2. **Check token expiration** before making authenticated requests
3. **Handle network errors** separately from API errors
4. **Log error details** including status codes for debugging
5. **Provide user-friendly messages** based on exception types
6. **Retry logic** for transient errors (5xx) with exponential backoff
7. **Don't expose sensitive information** from error messages to end users
