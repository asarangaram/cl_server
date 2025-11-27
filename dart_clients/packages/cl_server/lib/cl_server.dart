/// CL Server - Dart Client Library
///
/// A comprehensive Dart client library for interacting with CL Server microservices
/// including authentication, media store, and inference services.
///
/// ## Usage Example
///
/// ```dart
/// import 'package:cl_server/cl_server.dart';
///
/// void main() async {
///   final client = AuthClient(baseUrl: 'http://localhost:8002');
///
///   // Login
///   final token = await client.login('admin', 'admin');
///   print('Token: ${token.accessToken}');
///
///   // Get current user info
///   final user = await client.getCurrentUser(token.accessToken);
///   print('User: ${user.username}');
///
///   // Parse token to get claims
///   final tokenData = client.parseToken(token.accessToken);
///   print('Permissions: ${tokenData.permissions}');
///
///   client.close();
/// }
/// ```

// Export core exceptions
export 'src/core/exceptions.dart';

// Export models
export 'src/core/models/token.dart';
export 'src/core/models/token_data.dart';
export 'src/core/models/user.dart';
export 'src/core/models/entity.dart';
export 'src/core/models/pagination.dart';
export 'src/core/models/config.dart';

// Export HTTP client
export 'src/core/http_client.dart';

// Export authentication client
export 'src/auth/auth_client.dart';
export 'src/auth/token_manager.dart';
export 'src/auth/public_key_provider.dart';

// Export media store client
export 'src/media_store/media_store_client.dart';
export 'src/media_store/file_uploader.dart';

// Export inference client
export 'src/inference/inference_client.dart';
export 'src/inference/mqtt_event_listener.dart';

// Export inference models
export 'src/inference/models/job.dart';
export 'src/inference/models/bounding_box.dart';
export 'src/inference/models/face.dart';
export 'src/inference/models/image_embedding_result.dart';
export 'src/inference/models/face_detection_result.dart';
export 'src/inference/models/face_embedding_result.dart';
export 'src/inference/models/health_response.dart';
export 'src/inference/models/stats_response.dart';
export 'src/inference/models/cleanup_response.dart';
export 'src/inference/models/mqtt_event.dart';
