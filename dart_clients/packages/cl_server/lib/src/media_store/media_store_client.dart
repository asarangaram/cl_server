import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/http_client.dart';
import '../core/models/entity.dart';
import '../core/models/pagination.dart';
import '../core/models/config.dart';
import '../core/exceptions.dart';
import 'file_uploader.dart';

/// Client for CL Server Media Store Service
/// Provides stateless methods for managing media entities, files, and versioning
class MediaStoreClient {
  final CLHttpClient _httpClient;
  final FileUploader _fileUploader;

  MediaStoreClient({
    required String baseUrl,
    CLHttpClient? httpClient,
    Duration? requestTimeout,
  })  : _httpClient = httpClient ?? CLHttpClient(
          baseUrl: baseUrl,
          requestTimeout: requestTimeout ?? const Duration(seconds: 30),
        ),
        _fileUploader = FileUploader(
          httpClient ?? CLHttpClient(
            baseUrl: baseUrl,
            requestTimeout: requestTimeout ?? const Duration(seconds: 30),
          ),
        );

  // ============================================================
  // ENTITY CREATION ENDPOINTS
  // ============================================================

  /// Create a new collection entity
  Future<Entity> createCollection({
    required String token,
    required String label,
    String? description,
    int? parentId,
  }) async {
    try {
      _validateToken(token);

      final body = <String, String>{
        'is_collection': 'true',
        'label': label,
        if (description != null) 'description': description,
        if (parentId != null) 'parent_id': parentId.toString(),
      };

      // Encode as form-urlencoded
      final bodyStr = body.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final response = await _httpClient.post(
        '/entity/',
        body: bodyStr,
        token: token,
        isFormData: true,
      );

      if (response is Map<String, dynamic>) {
        try {
          return Entity.fromJson(response);
        } catch (parseError) {
          throw ValidationException(
            message: 'Failed to parse collection response: $parseError. Response: $response',
          );
        }
      }

      throw ValidationException(
        message: 'Unexpected response format for collection creation: $response',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to create collection: $e',
      );
    }
  }

  /// Create a new file-based entity with file upload
  Future<Entity> createEntity({
    required String token,
    required String label,
    required File file,
    String? description,
    int? parentId,
  }) async {
    try {
      _validateToken(token);

      final response = await _fileUploader.uploadFile(
        token: token,
        label: label,
        file: file,
        description: description,
        parentId: parentId,
        endpoint: '/entity/',
        isCollection: false,
      );

      if (response is Map<String, dynamic>) {
        try {
          return Entity.fromJson(response);
        } catch (parseError) {
          throw ValidationException(
            message: 'Failed to parse entity response: $parseError. Response: $response',
          );
        }
      }

      throw ValidationException(
        message: 'Unexpected response format for entity creation: $response',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to create entity: $e',
      );
    }
  }

  // ============================================================
  // ENTITY RETRIEVAL ENDPOINTS
  // ============================================================

  /// List entities with pagination
  Future<List<Entity>> listEntities({
    required String token,
    int? page,
    int? pageSize,
    int? version,
  }) async {
    try {
      _validateToken(token);

      final queryParams = {
        if (page != null) 'page': page.toString(),
        if (pageSize != null) 'page_size': pageSize.toString(),
        if (version != null) 'version': version.toString(),
      };

      final response = await _httpClient.get(
        '/entity/',
        token: token,
        queryParameters: queryParams,
      );

      // Handle paginated response format {items: [...], pagination: {...}}
      if (response is Map<String, dynamic> && response.containsKey('items')) {
        final items = response['items'] as List;
        return items
            .map((entity) => Entity.fromJson(entity as Map<String, dynamic>))
            .toList();
      }

      // Fallback: handle plain list response
      if (response is List) {
        return response
            .map((entity) => Entity.fromJson(entity as Map<String, dynamic>))
            .toList();
      }

      throw ValidationException(
        message: 'Unexpected response format for entity list',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to list entities: $e',
      );
    }
  }

  /// Get a specific entity by ID
  Future<Entity> getEntity({
    required String token,
    required int entityId,
    int? version,
  }) async {
    try {
      _validateToken(token);

      final queryParams = {
        if (version != null) 'version': version.toString(),
      };

      final response = await _httpClient.get(
        '/entity/$entityId',
        token: token,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response is Map<String, dynamic>) {
        return Entity.fromJson(response);
      }

      throw ValidationException(
        message: 'Unexpected response format for entity info',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to get entity: $e',
      );
    }
  }

  // ============================================================
  // ENTITY UPDATE ENDPOINTS
  // ============================================================

  /// Update an entity (full update via PUT)
  Future<Entity> updateEntity({
    required String token,
    required int entityId,
    required String label,
    required bool isCollection,
    String? description,
    int? parentId,
    File? file,
  }) async {
    try {
      _validateToken(token);

      if (file != null) {
        // Update with file upload
        final response = await _fileUploader.uploadFile(
          token: token,
          label: label,
          file: file,
          description: description,
          parentId: parentId,
          endpoint: '/entity/$entityId',
          method: 'PUT',
        );

        if (response is Map<String, dynamic>) {
          return Entity.fromJson(response);
        }
      } else {
        // Update without file - send as multipart form-data (no file)
        final uri = Uri.parse('${_httpClient.baseUrl}/entity/$entityId');
        final request = http.MultipartRequest('PUT', uri);

        request.headers['Authorization'] = 'Bearer $token';
        request.fields['is_collection'] = isCollection.toString();
        request.fields['label'] = label;
        if (description != null) {
          request.fields['description'] = description;
        }
        if (parentId != null) {
          request.fields['parent_id'] = parentId.toString();
        }

        final streamedResponse = await request.send()
            .timeout(_httpClient.requestTimeout ?? const Duration(seconds: 30));

        final responseBody = await streamedResponse.stream.bytesToString();

        if (streamedResponse.statusCode >= 400) {
          _handleErrorResponse(streamedResponse.statusCode, responseBody);
        }

        final response = jsonDecode(responseBody);
        if (response is Map<String, dynamic>) {
          return Entity.fromJson(response);
        }
      }

      throw ValidationException(
        message: 'Unexpected response format for entity update',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to update entity: $e',
      );
    }
  }

  /// Partial update an entity (PATCH)
  Future<Entity> patchEntity({
    required String token,
    required int entityId,
    String? label,
    String? description,
    int? parentId,
    File? file,
  }) async {
    try {
      _validateToken(token);

      if (file != null) {
        // File uploads use PUT method, not PATCH
        // Redirect to updateEntity which uses PUT with multipart form-data
        return updateEntity(
          token: token,
          entityId: entityId,
          label: label ?? 'File Update',
          isCollection: false,
          description: description,
          parentId: parentId,
          file: file,
        );
      } else {
        // Patch without file
        final bodyFields = <String, dynamic>{};
        if (label != null) bodyFields['label'] = label;
        if (description != null) bodyFields['description'] = description;
        if (parentId != null) bodyFields['parent_id'] = parentId;

        if (bodyFields.isEmpty) {
          throw ValidationException(
            message: 'At least one field must be provided for patch',
          );
        }

        // Wrap in 'body' key for FastAPI embed=True
        final body = {'body': bodyFields};

        final response = await _httpClient.patch(
          '/entity/$entityId',
          body: body,
          token: token,
        );

        if (response is Map<String, dynamic>) {
          return Entity.fromJson(response);
        }
      }

      throw ValidationException(
        message: 'Unexpected response format for entity patch',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to patch entity: $e',
      );
    }
  }

  // ============================================================
  // ENTITY DELETION ENDPOINTS
  // ============================================================

  /// Hard delete a single entity
  Future<void> deleteEntity({
    required String token,
    required int entityId,
  }) async {
    try {
      _validateToken(token);
      await _httpClient.delete('/entity/$entityId', token: token);
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to delete entity: $e',
      );
    }
  }

  /// Soft delete an entity (mark as deleted without removing)
  Future<Entity> softDeleteEntity({
    required String token,
    required int entityId,
  }) async {
    try {
      _validateToken(token);

      final body = {'is_deleted': true};

      final response = await _httpClient.patch(
        '/entity/$entityId',
        body: body,
        token: token,
      );

      if (response is Map<String, dynamic>) {
        return Entity.fromJson(response);
      }

      throw ValidationException(
        message: 'Unexpected response format for soft delete',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to soft delete entity: $e',
      );
    }
  }

  /// Delete all entities (hard delete)
  Future<void> deleteAllEntities({
    required String token,
  }) async {
    try {
      _validateToken(token);
      await _httpClient.delete('/entity/', token: token);
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to delete all entities: $e',
      );
    }
  }

  // ============================================================
  // VERSIONING ENDPOINTS
  // ============================================================

  /// Get all versions of an entity
  Future<List<Entity>> getVersions({
    required String token,
    required int entityId,
    int? page,
    int? pageSize,
  }) async {
    try {
      _validateToken(token);

      final queryParams = {
        if (page != null) 'page': page.toString(),
        if (pageSize != null) 'page_size': pageSize.toString(),
      };

      final response = await _httpClient.get(
        '/entity/$entityId/versions',
        token: token,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response is List) {
        try {
          return response
              .map((versionData) {
                // Ensure id field exists for Entity parsing
                final data = versionData as Map<String, dynamic>;
                if (!data.containsKey('id')) {
                  data['id'] = entityId;
                }
                return Entity.fromJson(data);
              })
              .toList();
        } catch (e) {
          throw ValidationException(
            message: 'Failed to parse version data: $e',
          );
        }
      }

      throw ValidationException(
        message: 'Unexpected response format for versions list',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to get versions: $e',
      );
    }
  }

  /// Get a specific version of an entity
  Future<Entity> getVersion({
    required String token,
    required int entityId,
    required int versionNumber,
  }) async {
    try {
      _validateToken(token);

      final queryParams = {'version': versionNumber.toString()};

      final response = await _httpClient.get(
        '/entity/$entityId/versions',
        token: token,
        queryParameters: queryParams,
      );

      if (response is Map<String, dynamic>) {
        // Ensure id field exists for Entity parsing
        if (!response.containsKey('id')) {
          response['id'] = entityId;
        }
        return Entity.fromJson(response);
      }

      throw ValidationException(
        message: 'Unexpected response format for version info',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to get version: $e',
      );
    }
  }

  // ============================================================
  // ADMIN CONFIGURATION ENDPOINTS
  // ============================================================

  /// Get current service configuration
  Future<ConfigResponse> getConfig({
    required String token,
  }) async {
    try {
      _validateToken(token);

      final response = await _httpClient.get('/admin/config', token: token);

      if (response is Map<String, dynamic>) {
        return ConfigResponse.fromJson(response);
      }

      throw ValidationException(
        message: 'Unexpected response format for config',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to get config: $e',
      );
    }
  }

  /// Update read authentication requirement
  Future<ConfigResponse> setReadAuth({
    required String token,
    required bool readAuthEnabled,
  }) async {
    try {
      _validateToken(token);

      final body = {'enabled': readAuthEnabled};

      final response = await _httpClient.put(
        '/admin/config/read-auth',
        body: body,
        token: token,
      );

      if (response is Map<String, dynamic>) {
        return ConfigResponse.fromJson(response);
      }

      throw ValidationException(
        message: 'Unexpected response format for config update',
      );
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'Failed to set read auth: $e',
      );
    }
  }

  // ============================================================
  // UTILITY METHODS
  // ============================================================

  /// Validate that a token is not expired
  void _validateToken(String token) {
    // Token validation can be added if needed
    // For now, trust that the server will validate the token
  }

  /// Handle error responses from HTTP requests
  void _handleErrorResponse(int statusCode, String responseBody) {
    try {
      final errorData = jsonDecode(responseBody);
      if (errorData is Map<String, dynamic> && errorData.containsKey('detail')) {
        throw CLServerException(
          message: errorData['detail'] ?? 'Unknown error',
          statusCode: statusCode,
        );
      } else if (errorData is List) {
        throw CLServerException(
          message: jsonEncode(errorData),
          statusCode: statusCode,
        );
      } else {
        throw CLServerException(
          message: errorData.toString(),
          statusCode: statusCode,
        );
      }
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        message: 'HTTP $statusCode: $responseBody',
        statusCode: statusCode,
      );
    }
  }

  /// Close the HTTP client
  void close() {
    _httpClient.close();
  }
}
