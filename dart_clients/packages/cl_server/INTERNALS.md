# CL Server Dart Client - Internal Design Documentation

This document describes the internal architecture, design decisions, and technical rationale for the CL Server Dart client library.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Design Decisions](#design-decisions)
- [Implementation Details](#implementation-details)
- [Security Considerations](#security-considerations)
- [Performance Considerations](#performance-considerations)
- [Limitations and Trade-offs](#limitations-and-trade-offs)
- [Future Enhancements](#future-enhancements)

---

## Architecture Overview

### Service-Based Architecture

The library is organized around three independent microservices:

```
cl_server/
├── src/
│   ├── auth/              # Authentication Service
│   │   ├── auth_client.dart
│   │   ├── token_manager.dart
│   │   └── public_key_provider.dart
│   ├── media_store/       # Media Store Service
│   │   ├── media_store_client.dart
│   │   └── file_uploader.dart
│   ├── inference/         # Inference Service
│   │   ├── inference_client.dart
│   │   ├── mqtt_event_listener.dart
│   │   └── models/
│   └── core/              # Shared Components
│       ├── http_client.dart
│       ├── exceptions.dart
│       └── models/
```

**Rationale:** Each service client is independent and can be used separately. This allows applications to include only the services they need, reducing dependency bloat.

### Stateless Client Pattern

All client classes (`AuthClient`, `MediaStoreClient`, `InferenceClient`) are intentionally stateless:

- **No internal token storage** - Tokens are passed as parameters to each authenticated request
- **No session management** - Application controls token lifecycle
- **No side effects** - Clients don't modify global state
- **Thread-safe** - Multiple instances can coexist without interference

**Benefits:**
1. **Simplifies testing** - No need to manage client state between tests
2. **Prevents state-related bugs** - No stale tokens or race conditions
3. **Explicit control** - Application decides when and how to store tokens
4. **Reusable across contexts** - Same client instance can handle multiple users

**Trade-offs:**
- Applications must implement their own token storage
- Token must be passed to every authenticated request
- No automatic token refresh

**Example Pattern:**
```dart
// 1. Authenticate
final token = await authClient.login(username, password);

// 2. Store token (application responsibility)
await secureStorage.write('auth_token', token.accessToken);

// 3. Use token for requests
final user = await authClient.getCurrentUser(token.accessToken);

// 4. Check expiration before requests
if (authClient.isTokenExpired(token.accessToken)) {
  // Re-authenticate
}
```

### HTTP Client Abstraction

The `CLHttpClient` class provides a unified HTTP interface for all services:

**Features:**
- Automatic JSON encoding/decoding
- Consistent error handling and exception mapping
- Support for query parameters, headers, and request bodies
- Form data encoding for authentication
- DELETE requests with JSON body (for cleanup operations)

**Error Mapping:**
```dart
HTTP Status → Exception Class
400         → ValidationException
401         → AuthenticationException
403         → AuthorizationException
404         → NotFoundException
409         → DuplicateResourceException
5xx         → ServerException
```

**Rationale:** Centralizing HTTP logic ensures consistent behavior across all services and simplifies maintenance.

---

## Design Decisions

### 1. JWT Token Parsing Without Signature Verification

**Decision:** The client parses JWT tokens to extract claims (userId, permissions, isAdmin, expiresAt) but does NOT verify ES256 signatures.

**Rationale:**
1. **Server is the source of truth** - The server validates tokens on every request
2. **Transport security via HTTPS** - Token integrity is protected in transit
3. **Simplifies dependencies** - No need for complex cryptographic libraries
4. **Client-side claims inspection** - Enables permission checks and UI decisions without server roundtrip
5. **Extensible design** - Signature verification can be added later if needed

**Security Model:**
- Tokens are decoded for **convenience** (reading claims)
- Server performs **actual validation** (signature, expiration, revocation)
- HTTPS ensures tokens aren't tampered with in transit
- Applications should treat tokens as opaque strings for authentication

**What the client does:**
- Parse token structure (header.payload.signature)
- Base64-decode payload
- Extract claims (sub, permissions, admin, exp)
- Check expiration timestamp

**What the client does NOT do:**
- Verify ES256 signature
- Validate issuer (iss)
- Check audience (aud)
- Verify token hasn't been revoked

**Example:**
```dart
final tokenData = authClient.parseToken(token.accessToken);

// Safe: Read claims for UI decisions
if (tokenData.isAdmin) {
  showAdminPanel();
}

// Safe: Check expiration before request
if (tokenData.isExpired) {
  await reAuthenticate();
}

// UNSAFE: Don't trust claims for security decisions
// Always let server validate permissions
```

### 2. Type-Safe Result Models

**Decision:** Separate model classes for each inference result type (`ImageEmbeddingResult`, `FaceDetectionResult`, `FaceEmbeddingResult`) instead of a single polymorphic result.

**Rationale:**
1. **Compile-time type safety** - IDE autocomplete and type checking
2. **Clear documentation** - Each result type is self-documenting
3. **Easier testing** - Mock specific result types
4. **Future-proof** - Easy to add new result types

**Trade-offs:**
- `Job.result` is still `Map<String, dynamic>` for flexibility
- Applications must pattern match on `taskType` to parse results
- Slightly more code than a single polymorphic class

**Usage Pattern:**
```dart
final job = await inferenceClient.getJob(jobId);

if (job.status == 'completed' && job.result != null) {
  switch (job.taskType) {
    case 'image_embedding':
      final result = ImageEmbeddingResult.fromJson(job.result!);
      print('Embedding dimension: ${result.embeddingDimension}');
      break;
    case 'face_detection':
      final result = FaceDetectionResult.fromJson(job.result!);
      print('Detected ${result.faceCount} faces');
      break;
    case 'face_embedding':
      final result = FaceEmbeddingResult.fromJson(job.result!);
      print('Embedded ${result.faceCount} faces');
      break;
  }
}
```

### 3. Callback-Based MQTT Event Handling

**Decision:** `MqttEventListener` uses callback functions instead of Dart Streams or Futures.

**Rationale:**
1. **Simplicity** - Single callback per listener, easy to understand
2. **Matches MQTT pattern** - Publish-subscribe naturally fits callbacks
3. **Predictable behavior** - No stream subscription management
4. **Minimal overhead** - Direct function invocation

**Trade-offs:**
- Less composable than Streams
- No built-in backpressure handling
- Single callback per listener instance

**Alternative Considered:** Dart Streams
- More idiomatic Dart
- Better composability with stream operators
- Rejected due to added complexity for simple use case

### 4. Optional Dependency Pattern for MQTT

**Decision:** MQTT support (`mqtt5_client`) is an optional dependency, not required for core functionality.

**Rationale:**
1. **Reduces bloat** - Applications not using real-time notifications don't need MQTT
2. **Graceful degradation** - Core REST API works without MQTT
3. **Flexible deployment** - Can use polling instead of MQTT if needed

**Implementation:**
- MQTT client is imported statically (not dynamically)
- Applications can choose to use REST polling or MQTT events
- Both approaches are equally supported

### 5. Snake Case ↔ Camel Case Conversion

**Decision:** Automatic conversion between Python API's snake_case and Dart's camelCase.

**Rationale:**
1. **Idiomatic Dart** - Dart convention is camelCase
2. **Idiomatic Python** - Python/FastAPI convention is snake_case
3. **Transparent conversion** - Developers work with natural naming in each language

**Mapping Examples:**
```
JSON (snake_case)     →  Dart (camelCase)
job_id                →  jobId
task_type             →  taskType
media_store_id        →  mediaStoreId
created_at            →  createdAt
error_message         →  errorMessage
embedding_dimension   →  embeddingDimension
stored_in_vector_db   →  storedInVectorDb
```

**Implementation:** Each model class implements `fromJson()` and `toJson()` with explicit field mapping.

---

## Implementation Details

### Token Lifecycle

```
┌─────────────────────────────────────────────────────────┐
│ 1. Login                                                │
│    authClient.login(username, password)                 │
│    → Returns Token{accessToken, tokenType}             │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ 2. Application Stores Token                            │
│    await storage.write('token', token.accessToken)      │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ 3. Parse Token (Optional)                              │
│    tokenData = authClient.parseToken(token)             │
│    → Extract userId, permissions, isAdmin, expiresAt   │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ 4. Use Token for Requests                              │
│    user = await authClient.getCurrentUser(token)        │
│    entity = await mediaClient.createEntity(token, ...)  │
│    job = await inferenceClient.createJob(token, ...)    │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ 5. Check Expiration                                     │
│    if (authClient.isTokenExpired(token)) {              │
│      // Re-authenticate                                 │
│    }                                                     │
└─────────────────────────────────────────────────────────┘
```

### Request/Response Flow

```
Application
    ↓ (calls client method)
Client (AuthClient/MediaStoreClient/InferenceClient)
    ↓ (validates token if needed)
    ↓ (builds request)
CLHttpClient
    ↓ (HTTP request)
Server (FastAPI)
    ↓ (validates token signature)
    ↓ (checks permissions)
    ↓ (processes request)
    ↓ (returns JSON response)
CLHttpClient
    ↓ (maps status codes to exceptions)
    ↓ (parses JSON)
Client
    ↓ (converts to model objects)
Application
```

### Error Handling Strategy

**Principle:** Fail fast with specific, actionable exceptions.

**Implementation:**
1. HTTP client maps status codes to exception types
2. Exceptions include status code, message, and raw response body
3. Applications catch specific exceptions for targeted error handling
4. Base `CLServerException` catches all library errors

**Example Flow:**
```dart
try {
  final user = await authClient.createUser(...);
} on DuplicateResourceException {
  // Handle duplicate username
  showError('Username already exists');
} on AuthorizationException {
  // Handle permission denied
  showError('You need admin privileges');
} on ValidationException catch (e) {
  // Handle validation errors
  showError('Invalid input: ${e.message}');
} on CLServerException catch (e) {
  // Catch-all for unexpected errors
  logError(e);
  showError('An unexpected error occurred');
}
```

### File Upload Implementation

The `MediaStoreClient` uses multipart/form-data for file uploads:

**Process:**
1. Read file from disk
2. Create multipart request with file and metadata
3. Send POST/PUT/PATCH request
4. Parse entity response

**Key Code:**
```dart
final request = http.MultipartRequest('POST', uri);
request.files.add(await http.MultipartFile.fromPath('file', file.path));
request.fields['label'] = label;
request.fields['is_collection'] = 'false';
if (description != null) request.fields['description'] = description;
```

**Rationale:** Multipart encoding is standard for file uploads and well-supported by FastAPI.

---

## Security Considerations

### Token Handling

**Best Practices:**
1. **Never log tokens** - Tokens are sensitive credentials
2. **Use HTTPS in production** - Protect tokens in transit
3. **Store tokens securely** - Use platform secure storage (Keychain, Keystore)
4. **Check expiration** - Validate before each request
5. **Clear on logout** - Remove tokens from storage

**Token Storage Options:**
- **Mobile:** `flutter_secure_storage` (Keychain/Keystore)
- **Web:** Encrypted cookies or sessionStorage (not localStorage)
- **Desktop:** Platform secure storage or encrypted files

### Permission Model

**Server-Side Enforcement:**
- All permission checks happen on the server
- Client-side checks are for UX only (hiding UI elements)
- Never trust client-side permission checks for security

**Permission Types:**
- `read` - Read entities
- `write` - Create/update entities
- `delete` - Delete entities
- `ai_inference_support` - Create/manage inference jobs
- `admin` - Full system access

**Client Usage:**
```dart
final tokenData = authClient.parseToken(token);

// UX decision: Hide button if no permission
if (!tokenData.hasPermission('ai_inference_support')) {
  hideInferenceButton();
}

// Server still validates permission on actual request
try {
  await inferenceClient.createJob(...);
} on AuthorizationException {
  // Server rejected due to missing permission
}
```

### Capability Tokens

**Job IDs as Capability Tokens:**
- `getJob(jobId)` doesn't require authentication
- Job ID acts as a capability token (knowledge = access)
- Secure because job IDs are UUIDs (unguessable)

**Rationale:**
- Simplifies result retrieval
- Enables sharing job results via URL
- Still secure due to UUID randomness (2^122 possible values)

**Security Properties:**
- Job IDs are cryptographically random UUIDs
- Guessing a valid job ID is computationally infeasible
- Job results don't contain sensitive user data
- Applications can implement additional access controls if needed

---

## Performance Considerations

### Request Timing

**Typical Latencies (local development):**
- Authentication: 50-100ms
- Entity operations: 20-50ms
- File uploads: 100ms-2s (depends on file size)
- Inference job creation: 50ms
- Job status check: 10-20ms

### Job Processing Times

**Inference Tasks (varies by hardware):**
- **Image Embedding (CLIP ViT-B/32):**
  - GPU: 100-200ms
  - CPU: 1-2s
- **Face Detection (RetinaFace):**
  - GPU: 50-100ms
  - CPU: 500-800ms
- **Face Embedding:**
  - GPU: 150-250ms
  - CPU: 2-3s

**Implications:**
- Use MQTT for real-time notifications (sub-second latency)
- Polling is acceptable for low-priority jobs (poll every 5-10s)
- Batch operations should use MQTT to avoid polling overhead

### MQTT Event Delivery

**Latencies:**
- Topic subscription: <100ms
- Message delivery: <10ms (local broker)
- Payload parsing: ~5ms
- Callback invocation: <1ms

**Best Practices:**
1. Keep callback functions lightweight
2. Offload heavy processing to background tasks
3. Use single MQTT connection for multiple job subscriptions
4. Disconnect when not actively monitoring jobs

### Memory Considerations

**Client Instances:**
- Each client instance maintains an HTTP client
- HTTP clients maintain connection pools
- Always call `close()` when done to release resources

**Best Practice:**
```dart
final authClient = AuthClient(baseUrl: authUrl);
final mediaClient = MediaStoreClient(baseUrl: mediaUrl);
final inferenceClient = InferenceClient(baseUrl: inferenceUrl);

try {
  // Use clients
} finally {
  authClient.close();
  mediaClient.close();
  inferenceClient.close();
}
```

---

## Limitations and Trade-offs

### 1. No Signature Verification

**Limitation:** Client doesn't verify JWT ES256 signatures.

**Impact:**
- Cannot detect tampered tokens client-side
- Must trust server for token validation

**Mitigation:**
- Use HTTPS to prevent token tampering in transit
- Server validates all tokens
- Acceptable for most use cases

**Future Enhancement:** Add optional signature verification with ES256 support.

### 2. Result Polymorphism

**Limitation:** `Job.result` is `Map<String, dynamic>`, not a typed union.

**Impact:**
- Applications must pattern match on `taskType`
- No compile-time guarantee of result structure
- Potential runtime errors if result structure changes

**Mitigation:**
- Provide typed result classes (`ImageEmbeddingResult`, etc.)
- Document result structures clearly
- Use `fromJson()` for safe parsing

**Future Enhancement:** Use sealed classes or union types when Dart supports them natively.

### 3. No Auto-Retry

**Limitation:** Failed requests are not automatically retried.

**Impact:**
- Transient network errors require manual retry
- Applications must implement retry logic

**Mitigation:**
- Server retries failed jobs (up to 3 times)
- Applications can implement exponential backoff
- MQTT notifications reduce need for polling retries

**Future Enhancement:** Add optional retry middleware with configurable policies.

### 4. No Token Refresh

**Limitation:** No automatic token refresh mechanism.

**Impact:**
- Applications must handle token expiration
- User may be logged out unexpectedly

**Mitigation:**
- Check `isTokenExpired()` before requests
- Implement refresh flow in application
- Server tokens have reasonable expiration (e.g., 24 hours)

**Future Enhancement:** Add refresh token support with automatic renewal.

### 5. Synchronous File Reading

**Limitation:** File uploads read entire file into memory.

**Impact:**
- Large files (>100MB) may cause memory pressure
- Not suitable for streaming uploads

**Mitigation:**
- Server enforces file size limits
- Most media files are <50MB
- Use chunked uploads for very large files (not yet implemented)

**Future Enhancement:** Add streaming upload support for large files.

---

## Future Enhancements

### Short-term (Next Release)

1. **Integration Tests**
   - Full test suite for all three services
   - Mock MQTT broker for event testing
   - Error scenario coverage

2. **Polling Utilities**
   - Helper function: `waitForJobCompletion(jobId, timeout)`
   - Batch job monitoring
   - Configurable polling intervals

3. **Result Parsing Helpers**
   - `Job.parseImageEmbeddingResult()`
   - `Job.parseFaceDetectionResult()`
   - `Job.parseFaceEmbeddingResult()`

### Medium-term

1. **Token Refresh**
   - Refresh token support
   - Automatic token renewal
   - Configurable refresh strategy

2. **Retry Middleware**
   - Automatic retry for transient errors
   - Exponential backoff
   - Configurable retry policies

3. **Streaming Uploads**
   - Chunked file uploads
   - Progress callbacks
   - Resume support

4. **WebSocket Support**
   - Alternative to MQTT for web applications
   - Server-Sent Events (SSE) for job progress

### Long-term

1. **Signature Verification**
   - Optional ES256 signature verification
   - Public key caching
   - Key rotation support

2. **Offline Support**
   - Queue requests when offline
   - Sync when connection restored
   - Conflict resolution

3. **Advanced Caching**
   - Entity metadata caching
   - Cache invalidation strategies
   - Optimistic updates

4. **Batch Operations**
   - Bulk entity creation
   - Bulk inference job submission
   - Transaction support

---

## Design Philosophy

### Principles

1. **Explicit over Implicit**
   - No hidden state or side effects
   - Clear, predictable behavior
   - Obvious error handling

2. **Simple over Clever**
   - Straightforward implementations
   - Minimal abstractions
   - Easy to understand and debug

3. **Safe over Fast**
   - Type safety where possible
   - Fail fast with clear errors
   - Validate inputs early

4. **Flexible over Opinionated**
   - Support multiple usage patterns
   - Don't force specific architectures
   - Provide building blocks, not frameworks

### Influences

- **Dart HTTP Package** - Standard HTTP client patterns
- **Retrofit (Java)** - Type-safe HTTP clients
- **FastAPI** - Modern API design patterns
- **Go's Error Handling** - Explicit error returns
- **Rust's Result Type** - Type-safe error handling

---

## Contributing

When extending this library, please follow these guidelines:

1. **Maintain stateless design** - Don't add internal state to clients
2. **Use explicit error types** - Create specific exceptions for new error cases
3. **Document design decisions** - Update this file with rationale
4. **Add tests** - Unit tests for models, integration tests for clients
5. **Follow naming conventions** - camelCase for Dart, snake_case for JSON
6. **Keep it simple** - Prefer simple solutions over clever abstractions

---

## Version History

### v0.2.0 - Inference Service
- Added `InferenceClient` for AI inference jobs
- Added `MqttEventListener` for real-time notifications
- Added 10 inference-specific models
- Enhanced `CLHttpClient` to support DELETE with body
- Added `mqtt5_client` optional dependency

### v0.1.0 - Initial Release
- `AuthClient` for authentication and user management
- `MediaStoreClient` for entity and file management
- Core HTTP client and exception handling
- JWT token parsing (without signature verification)
- Comprehensive model classes with JSON serialization

---

## References

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [JWT Specification (RFC 7519)](https://tools.ietf.org/html/rfc7519)
- [MQTT Protocol](https://mqtt.org/)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [HTTP Package](https://pub.dev/packages/http)
