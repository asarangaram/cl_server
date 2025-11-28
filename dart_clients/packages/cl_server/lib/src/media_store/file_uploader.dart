import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/http_client.dart';
import '../core/exceptions.dart';

/// File uploader utility for handling multipart form-data uploads
class FileUploader {
  final CLHttpClient _httpClient;

  FileUploader(this._httpClient);

  /// Upload a file as multipart form data
  /// Supports POST and PUT methods
  /// Returns the parsed JSON response as a Map
  Future<Map<String, dynamic>> uploadFile({
    required String token,
    String? label,
    required File file,
    String? description,
    int? parentId,
    required String endpoint,
    String method = 'POST',
    bool isCollection = false,
  }) async {
    try {
      if (!await file.exists()) {
        throw ValidationException(
          message: 'File does not exist: ${file.path}',
        );
      }

      // Create multipart request
      final uri = Uri.parse('${_httpClient.baseUrl}$endpoint');
      final request = _createMultipartRequest(
        method,
        uri,
        token: token,
        label: label,
        file: file,
        description: description,
        parentId: parentId,
        isCollection: isCollection,
      );

      // Send request
      final streamedResponse = await request.send()
          .timeout(_httpClient.requestTimeout ?? const Duration(seconds: 30));

      // Read response
      final responseBody = await streamedResponse.stream.bytesToString();

      // Handle errors
      if (streamedResponse.statusCode >= 400) {
        _handleErrorResponse(streamedResponse.statusCode, responseBody);
      }

      // Parse response
      return _parseJsonResponse(responseBody);
    } on CLServerException {
      rethrow;
    } catch (e) {
      throw CLServerException(
        message: 'File upload failed: $e',
      );
    }
  }

  /// Create a multipart request
  http.MultipartRequest _createMultipartRequest(
    String method,
    Uri uri, {
    required String token,
    String? label,
    required File file,
    String? description,
    int? parentId,
    bool isCollection = false,
  }) {
    final request = http.MultipartRequest(method, uri);

    // Add authorization header
    request.headers['Authorization'] = 'Bearer $token';

    // Add form fields based on HTTP method
    // PUT requires is_collection, PATCH does not
    if (method.toUpperCase() == 'PUT') {
      request.fields['is_collection'] = isCollection.toString();
      if (label != null) {
        request.fields['label'] = label;
      }
    } else if (method.toUpperCase() == 'PATCH') {
      // PATCH only sends the fields being updated
      if (label != null) {
        request.fields['label'] = label;
      }
    }

    if (description != null) {
      request.fields['description'] = description;
    }
    if (parentId != null) {
      request.fields['parent_id'] = parentId.toString();
    }

    // Add file (named 'image' for media store endpoint)
    request.files.add(
      http.MultipartFile(
        'image',
        file.openRead(),
        file.lengthSync(),
        filename: file.path.split('/').last,
      ),
    );

    return request;
  }

  /// Handle error responses
  void _handleErrorResponse(int statusCode, String responseBody) {
    try {
      final json = _parseJsonResponse(responseBody);
      final message = json['detail'] ?? 'Unknown error';

      switch (statusCode) {
        case 401:
          throw AuthenticationException(
            statusCode: statusCode,
            message: message.toString(),
            responseBody: responseBody,
          );
        case 403:
          throw AuthorizationException(
            statusCode: statusCode,
            message: message.toString(),
            responseBody: responseBody,
          );
        case 404:
          throw NotFoundException(
            statusCode: statusCode,
            message: message.toString(),
            responseBody: responseBody,
          );
        case 409:
          throw DuplicateResourceException(
            statusCode: statusCode,
            message: message.toString(),
            responseBody: responseBody,
          );
        case 400:
          throw ValidationException(
            statusCode: statusCode,
            message: message.toString(),
            responseBody: responseBody,
          );
        default:
          if (statusCode >= 500) {
            throw ServerException(
              statusCode: statusCode,
              message: message.toString(),
              responseBody: responseBody,
            );
          }
          throw CLServerException(
            statusCode: statusCode,
            message: message.toString(),
            responseBody: responseBody,
          );
      }
    } catch (e) {
      if (e is CLServerException) {
        rethrow;
      }
      throw CLServerException(
        statusCode: statusCode,
        message: 'Error handling response: $e',
        responseBody: responseBody,
      );
    }
  }

  /// Parse JSON response from string
  Map<String, dynamic> _parseJsonResponse(String responseBody) {
    if (responseBody.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else if (decoded is List) {
        // If it's a list, wrap it in a map
        return {'data': decoded};
      }
      // If it's something else, convert to string and wrap
      return {'data': decoded.toString()};
    } catch (e) {
      // If JSON decode fails, return the raw body as detail
      return {'detail': responseBody};
    }
  }
}
