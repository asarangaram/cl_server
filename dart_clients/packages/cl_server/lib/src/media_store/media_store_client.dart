import 'dart:io';
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
        // Update without file
        final body = {
          'label': label,
          'is_collection': isCollection,
          if (description != null) 'description': description,
          if (parentId != null) 'parent_id': parentId,
        };

        final response = await _httpClient.put(
          '/entity/$entityId',
          body: body,
          token: token,
        );

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
        // Patch with file upload
        final response = await _fileUploader.uploadFile(
          token: token,
          label: label,
          file: file,
          description: description,
          parentId: parentId,
          endpoint: '/entity/$entityId',
          method: 'PATCH',
        );

        if (response is Map<String, dynamic>) {
          return Entity.fromJson(response);
        }
      } else {
        // Patch without file
        final body = <String, dynamic>{};
        if (label != null) body['label'] = label;
        if (description != null) body['description'] = description;
        if (parentId != null) body['parent_id'] = parentId;

        if (body.isEmpty) {
          throw ValidationException(
            message: 'At least one field must be provided for patch',
          );
        }

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
        return response
            .map((entity) => Entity.fromJson(entity as Map<String, dynamic>))
            .toList();
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

      final body = {'read_auth_enabled': readAuthEnabled};

      final response = await _httpClient.put(
        '/admin/config',
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

  /// Close the HTTP client
  void close() {
    _httpClient.close();
  }
}
