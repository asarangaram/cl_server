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
  }) {
    final request = http.MultipartRequest(method, uri);

    // Add authorization header
    request.headers['Authorization'] = 'Bearer $token';

    // Add form fields
    if (label != null) {
      request.fields['label'] = label;
    }
    if (description != null) {
      request.fields['description'] = description;
    }
    if (parentId != null) {
      request.fields['parent_id'] = parentId.toString();
    }

    // Add file
    request.files.add(
      http.MultipartFile(
        'file',
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
      final json = Uri.splitQueryString(responseBody);
      if (json is Map<String, dynamic>) {
        return json;
      }
    } catch (e) {
      // Not URL encoded, try JSON parsing
    }

    // Try JSON parsing
    try {
      // Simple JSON parser for basic structures
      if (responseBody.startsWith('{')) {
        return _simpleJsonParse(responseBody);
      }
      if (responseBody.startsWith('[')) {
        return {'data': _simpleJsonParse(responseBody)};
      }
    } catch (e) {
      // Fall through to error handling
    }

    return {'detail': responseBody};
  }

  /// Simple JSON parser for basic structures
  Map<String, dynamic> _simpleJsonParse(String jsonString) {
    // Remove whitespace
    jsonString = jsonString.trim();

    // Handle empty object
    if (jsonString == '{}') {
      return {};
    }

    // Basic parsing for common cases
    // This is a simplified parser; for production, use a proper JSON library
    final map = <String, dynamic>{};

    // Remove outer braces
    if (jsonString.startsWith('{') && jsonString.endsWith('}')) {
      jsonString = jsonString.substring(1, jsonString.length - 1);
    }

    // Split by comma (simplified - doesn't handle nested objects)
    final pairs = _smartSplit(jsonString, ',');

    for (final pair in pairs) {
      final colonIndex = pair.indexOf(':');
      if (colonIndex > 0) {
        final key = pair.substring(0, colonIndex).trim();
        final value = pair.substring(colonIndex + 1).trim();

        // Remove quotes from key
        final cleanKey = key.replaceAll('"', '').replaceAll("'", '');

        // Parse value
        final parsedValue = _parseValue(value);
        map[cleanKey] = parsedValue;
      }
    }

    return map;
  }

  /// Smart split that respects quoted strings
  List<String> _smartSplit(String str, String delimiter) {
    final parts = <String>[];
    var current = '';
    var inQuotes = false;
    var quoteChar = '"';

    for (var i = 0; i < str.length; i++) {
      final char = str[i];

      if ((char == '"' || char == "'") && (i == 0 || str[i - 1] != '\\')) {
        if (!inQuotes) {
          inQuotes = true;
          quoteChar = char;
        } else if (char == quoteChar) {
          inQuotes = false;
        }
      }

      if (char == delimiter && !inQuotes) {
        if (current.isNotEmpty) {
          parts.add(current);
        }
        current = '';
      } else {
        current += char;
      }
    }

    if (current.isNotEmpty) {
      parts.add(current);
    }

    return parts;
  }

  /// Parse a JSON value
  dynamic _parseValue(String value) {
    value = value.trim();

    // null
    if (value == 'null') return null;

    // boolean
    if (value == 'true') return true;
    if (value == 'false') return false;

    // number
    try {
      if (value.contains('.')) {
        return double.parse(value);
      } else {
        return int.parse(value);
      }
    } catch (e) {
      // Not a number
    }

    // string
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      return value.substring(1, value.length - 1);
    }

    // If we can't parse it, return as string
    return value;
  }
}
