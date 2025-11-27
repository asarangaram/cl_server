# Task 2: Image Embedding Test Suite Implementation Guide

**Status**: Plan Complete, Ready for Implementation
**Created**: 2025-11-27
**Plan Reference**: `/Users/anandasarangaram/.claude/plans/structured-sauteeing-elephant.md`

---

## Quick Reference

### Test Execution Commands
```bash
# Basic execution with required environment variable
CL_SERVER_TESTDIR=/tmp/cl_server_test dart test test/integration/image_embedding_store_test.dart

# With custom service URLs (for test instances)
CL_SERVER_TESTDIR=/tmp/cl_server_test \
AUTH_SERVICE_URL=http://test-server:8000 \
MEDIA_STORE_URL=http://test-server:8001 \
INFERENCE_SERVICE_URL=http://test-server:8002 \
MQTT_BROKER_HOST=test-server \
dart test test/integration/image_embedding_store_test.dart

# Run specific test group
dart test -n "Happy Path" test/integration/image_embedding_store_test.dart

# With timeout and verbose output
CL_SERVER_TESTDIR=/tmp/cl_server_test dart test -t 180 --verbose test/integration/image_embedding_store_test.dart
```

---

## Environment Setup Requirements

### Required Environment Variables
1. **CL_SERVER_TESTDIR** (MANDATORY)
   - Purpose: Base directory for test artifacts
   - Example: `/tmp/cl_server_test`
   - Behavior: Abort with clear error if not set
   - Validation: Must exist and be writable

### Configurable Environment Variables (Optional)
1. **AUTH_SERVICE_URL**
   - Default: `http://localhost:8000`
   - Override: Set to test instance URL

2. **MEDIA_STORE_URL**
   - Default: `http://localhost:8001`
   - Override: Set to test instance URL

3. **INFERENCE_SERVICE_URL**
   - Default: `http://localhost:8002`
   - Override: Set to test instance URL

4. **MQTT_BROKER_HOST**
   - Default: `localhost`
   - Override: Set to test instance host

5. **MQTT_BROKER_PORT**
   - Default: `1883`
   - Override: Set to test instance port

---

## Files to Create

### 1. Main Test Suite
**File**: `dart_clients/packages/cl_server/test/integration/image_embedding_store_test.dart`
- 40+ tests organized in 3 groups
- Framework: Dart `test` package (v1.25.0+)
- Execution: Sequential (one test at a time)

### 2. Test Helper Classes
**File**: `dart_clients/packages/cl_server/test/integration/image_embedding_helpers.dart`

Contains:
- `TestEnvironment` class: Environment variable validation and configuration
- `ImageEmbeddingTestHelper` class: Clients management and test operations

Key methods:
- `initialize(testName)`: Creates artifact directory, initializes clients
- `uploadTestImage(imagePath)`: Uploads image, returns media_store_id
- `submitEmbeddingJob(mediaStoreId)`: Submits job, returns job_id
- `waitForJobCompletion(jobId, ...)`: Configurable MQTT/polling wait mechanism
- `cleanup()`: Removes created resources

### 3. Test Image Manifest
**File**: `dart_clients/packages/cl_server/test/fixtures/image_manifest.json`

Format:
```json
{
  "test_images": [
    {
      "name": "test_image_1",
      "absolute_path": "/absolute/path/to/image.jpg",
      "description": "Primary test image"
    }
  ]
}
```

Purpose: Centralized image path management, easily changeable

### 4. Test Image Loader
**File**: `dart_clients/packages/cl_server/test/fixtures/test_image_loader.dart`

Singleton pattern with:
- `initialize()`: Load and validate manifest
- `getPrimaryImage()`: Get first test image
- `getSecondaryImage()`: Get second test image
- `getRandomImage()`: Get random image from manifest
- Validation: Fail fast if images missing

---

## Test Artifact Management

### Directory Structure
```
$CL_SERVER_TESTDIR/dart_clients/cl_server/
├── test_complete_workflow_mqtt_<timestamp>/
│   ├── jobs.txt              # Line-separated job IDs
│   ├── media.txt             # Line-separated media IDs
│   └── test.log              # Optional test output
├── test_invalid_credentials_<timestamp>/
│   └── test.log
└── ...
```

### Artifact Lifecycle
1. **Test Start**: Clear existing artifact folder completely
2. **Test Run**: Log all created resource IDs (jobs, media)
3. **Test Pass**: Optionally clean up (or keep for inspection)
4. **Test Fail**: Keep ALL artifacts for debugging
5. **Next Run**: Clear folder before test execution

### Resource Tracking
- Each test gets unique folder with timestamp
- Create `jobs.txt` and `media.txt` files during test
- Use these for manual cleanup if test crashes

---

## Test Organization

### Test Groups (3 total)

#### 1. Image Embedding - Happy Path (10 tests)
Tests normal workflow with different configurations:
- MQTT primary mechanism
- Polling only mechanism
- Hybrid (MQTT + fallback) mechanism
- Multiple sequential jobs
- Concurrent jobs (MQTT and polling variants)
- Job priorities
- Embedding verification
- Timestamp progression
- Custom collections

#### 2. Image Embedding - Error Scenarios (12 tests)
Tests error handling and edge cases:
- Invalid credentials
- Missing/invalid files
- Invalid media store IDs
- Missing required data
- MQTT timeout with polling fallback
- Polling timeout
- Network errors
- MQTT-only with unavailable broker
- Concurrent job failures
- Job cancellation
- Large timeout values

#### 3. Image Embedding - Integration Edge Cases (8+ tests)
Tests system robustness:
- Rapid successive submissions
- Different image formats
- Embedding consistency
- Orphaned resource cleanup
- Token expiration handling
- Permission-based access control
- Concurrent clients
- Variable job speed with hybrid mode

---

## Key Implementation Details

### Environment Validation
```
setUpAll() must:
1. Call TestEnvironment.initialize()
2. Validate CL_SERVER_TESTDIR is set
3. Load service URLs (with defaults)
4. Load and validate test images
5. Exit(1) with clear message if any validation fails
```

### Per-Test Setup
```
setUp() must:
1. Generate unique test name with timestamp
2. Initialize helper with test name
3. Clear and create artifact directory
4. Create all clients
5. Authenticate once
```

### Per-Test Teardown
```
tearDown() must:
1. Attempt cleanup of created resources
2. NOT fail test on cleanup errors
3. Log cleanup failures as warnings
4. Keep artifacts for debugging
```

### Resource Cleanup
- Best-effort cleanup (non-blocking)
- Log failures but don't fail tests
- All job and media IDs tracked in helper
- Files record IDs for manual cleanup

---

## Test Execution Patterns

### MQTT-Only Tests
```dart
final job = await helper.waitForJobCompletion(
  jobId,
  useMqtt: true,
  usePolling: false,  // Disable polling
);
```

### Polling-Only Tests
```dart
final job = await helper.waitForJobCompletion(
  jobId,
  useMqtt: false,     // Disable MQTT
  usePolling: true,
);
```

### Hybrid Tests
```dart
final job = await helper.waitForJobCompletion(
  jobId,
  useMqtt: true,
  usePolling: true,   // Try MQTT first, fallback to polling
  mqttTimeout: Duration(seconds: 30),
  pollInterval: Duration(seconds: 2),
);
```

### Concurrent Tests
```dart
final jobs = await Future.wait([
  helper.submitEmbeddingJob(id1),
  helper.submitEmbeddingJob(id2),
  helper.submitEmbeddingJob(id3),
]);
```

---

## Test Data & Fixtures

### Test Users
- Username: `admin`
- Password: `admin`
- Permissions: Full access (for tests)

### Test Images
- From `/demos/images/` directory
- Configured via manifest.json
- Can change paths by updating manifest
- Multiple formats: JPG, PNG

### Test Collections
- Created per test
- Automatically associated with media upload
- Stored in Qdrant vector DB

---

## Dependencies

### Dart Test Package
- Version: `^1.25.0`
- Already in pubspec.yaml

### Client Packages
- `auth_client`: Authentication
- `media_store_client`: Media upload
- `inference_client`: Job submission & MQTT
- `mqtt5_client`: MQTT events (via inference_client)

### No Additional Dependencies Required
- Use existing test infrastructure
- No mocking libraries needed
- All real service integration

---

## Expected Test Results

### Performance Metrics
- MQTT completion: 50-70ms
- Polling detection: 2-4 seconds
- Concurrent job handling: No race conditions
- Resource cleanup: < 1 second per resource

### Success Indicators
- All 40+ tests pass
- No resource leaks
- Artifacts properly logged
- Clear error messages on failures

---

## Troubleshooting Guide

### Test Fails: "CL_SERVER_TESTDIR not set"
**Solution**: Set the environment variable before running tests
```bash
export CL_SERVER_TESTDIR=/tmp/cl_server_test
dart test test/integration/image_embedding_store_test.dart
```

### Test Fails: "Connection refused"
**Possible Causes**:
- Service not running on configured port
- Wrong service URL in environment variable

**Solution**: Verify service URLs match your setup
```bash
curl http://localhost:8000/api/health  # Check if services running
```

### Test Fails: "Image file not found"
**Cause**: Images configured in manifest don't exist

**Solution**: Update manifest.json with correct absolute paths
```bash
ls /demos/images/  # List available images
```

### Test Leaves Artifacts Behind
**Normal Behavior**: Failed tests keep artifacts for debugging

**To Clean Up**:
```bash
rm -rf $CL_SERVER_TESTDIR/dart_clients/cl_server/*
```

---

## Next Steps for Implementation

1. **Create Test Helper** (`image_embedding_helpers.dart`)
   - TestEnvironment class with validation
   - ImageEmbeddingTestHelper with all methods

2. **Create Test Image Loader** (`test_image_loader.dart`)
   - Singleton for image manifest management
   - Validation of image files

3. **Create Image Manifest** (`image_manifest.json`)
   - List of test images with absolute paths
   - Can be updated without code changes

4. **Create Main Test Suite** (`image_embedding_store_test.dart`)
   - setUpAll/setUp/tearDown/tearDownAll
   - 3 test groups with 40+ tests
   - Use helpers for test operations

5. **Run Tests**
   ```bash
   CL_SERVER_TESTDIR=/tmp/cl_server_test \
   dart test test/integration/image_embedding_store_test.dart
   ```

6. **Verify Success**
   - All 40+ tests pass
   - Artifacts properly created
   - No resource leaks

---

## Additional Resources

- Plan file: `/Users/anandasarangaram/.claude/plans/structured-sauteeing-elephant.md`
- Task 1 (CLI App): Complete and tested
- Dart test package docs: https://pub.dev/packages/test
- Existing test patterns: `test/integration/auth_login_test.dart`

