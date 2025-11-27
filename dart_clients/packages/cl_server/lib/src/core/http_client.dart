import 'dart:convert';
import 'package:http/http.dart' as http;
import 'exceptions.dart';

/// HTTP client wrapper for making requests to CL Server APIs
class CLHttpClient {
  final String baseUrl;
  final Duration requestTimeout;
  final http.Client _httpClient;

  CLHttpClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _httpClient = httpClient ?? http.Client();

  /// Make a GET request
  Future<dynamic> get(
    String path, {
    String? token,
    Map<String, String>? queryParameters,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final headers = _buildHeaders(token: token);

    try {
      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(requestTimeout);
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Make a POST request
  Future<dynamic> post(
    String path, {
    required dynamic body,
    String? token,
    bool isFormData = false,
  }) async {
    final uri = _buildUri(path);
    final headers = _buildHeaders(token: token, isFormData: isFormData);

    try {
      http.Response response;

      if (isFormData && body is Map<String, String>) {
        response = await http.post(
          uri,
          headers: headers,
          body: body,
        ).timeout(requestTimeout);
      } else {
        final bodyStr = body is String ? body : jsonEncode(body);
        response = await _httpClient
            .post(uri, headers: headers, body: bodyStr)
            .timeout(requestTimeout);
      }

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Make a PUT request
  Future<dynamic> put(
    String path, {
    required dynamic body,
    String? token,
    bool isFormData = false,
  }) async {
    final uri = _buildUri(path);
    final headers = _buildHeaders(token: token, isFormData: isFormData);

    try {
      http.Response response;

      if (isFormData && body is Map<String, String>) {
        response = await http.put(
          uri,
          headers: headers,
          body: body,
        ).timeout(requestTimeout);
      } else {
        final bodyStr = body is String ? body : jsonEncode(body);
        response = await _httpClient
            .put(uri, headers: headers, body: bodyStr)
            .timeout(requestTimeout);
      }

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Make a PATCH request
  Future<dynamic> patch(
    String path, {
    required dynamic body,
    String? token,
  }) async {
    final uri = _buildUri(path);
    final headers = _buildHeaders(token: token);
    final bodyStr = body is String ? body : jsonEncode(body);

    try {
      final response = await _httpClient
          .patch(uri, headers: headers, body: bodyStr)
          .timeout(requestTimeout);
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Make a DELETE request
  Future<dynamic> delete(
    String path, {
    String? token,
    dynamic body,
  }) async {
    final uri = _buildUri(path);
    final headers = _buildHeaders(token: token);

    try {
      http.Response response;

      if (body != null) {
        final bodyStr = body is String ? body : jsonEncode(body);
        // Use a custom DELETE request with body
        final request = http.Request('DELETE', uri)
          ..headers.addAll(headers)
          ..body = bodyStr;
        response = await _httpClient.send(request).then(http.Response.fromStream).timeout(requestTimeout);
      } else {
        response = await _httpClient
            .delete(uri, headers: headers)
            .timeout(requestTimeout);
      }

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Build the full URI from path and query parameters
  Uri _buildUri(String path, [Map<String, String>? queryParameters]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final url = '$baseUrl$cleanPath';

    if (queryParameters == null || queryParameters.isEmpty) {
      return Uri.parse(url);
    }

    return Uri.parse(url).replace(queryParameters: queryParameters);
  }

  /// Build request headers
  Map<String, String> _buildHeaders({
    String? token,
    bool isFormData = false,
  }) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (!isFormData) {
      headers['Content-Type'] = 'application/json';
    }

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// Handle HTTP response
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Success
      if (response.body.isEmpty) {
        return null;
      }
      try {
        return jsonDecode(response.body);
      } catch (e) {
        return response.body;
      }
    } else {
      // Error
      dynamic responseBody;
      try {
        responseBody = jsonDecode(response.body);
      } catch (e) {
        responseBody = response.body;
      }

      final errorMessage = _extractErrorMessage(responseBody);

      switch (response.statusCode) {
        case 400:
          throw ValidationException(
            message: errorMessage,
            statusCode: 400,
            responseBody: responseBody,
          );
        case 401:
          throw AuthenticationException(
            message: errorMessage,
            statusCode: 401,
            responseBody: responseBody,
          );
        case 403:
          throw AuthorizationException(
            message: errorMessage,
            statusCode: 403,
            responseBody: responseBody,
          );
        case 404:
          throw NotFoundException(
            message: errorMessage,
            statusCode: 404,
            responseBody: responseBody,
          );
        case 409:
          throw DuplicateResourceException(
            message: errorMessage,
            statusCode: 409,
            responseBody: responseBody,
          );
        default:
          if (response.statusCode >= 500) {
            throw ServerException(
              message: errorMessage,
              statusCode: response.statusCode,
              responseBody: responseBody,
            );
          } else {
            throw CLServerException(
              message: errorMessage,
              statusCode: response.statusCode,
              responseBody: responseBody,
            );
          }
      }
    }
  }

  /// Extract error message from response
  String _extractErrorMessage(dynamic responseBody) {
    if (responseBody is Map<String, dynamic>) {
      if (responseBody.containsKey('detail')) {
        final detail = responseBody['detail'];
        if (detail is String) {
          return detail;
        } else if (detail is List && detail.isNotEmpty) {
          return detail.first.toString();
        }
      }
    }
    return responseBody.toString();
  }

  /// Handle network errors
  CLServerException _handleError(dynamic error) {
    if (error is CLServerException) {
      return error;
    }

    if (error is http.ClientException) {
      return CLServerException(
        message: 'Network error: ${error.message}',
        responseBody: error,
      );
    }

    return CLServerException(
      message: 'Error: $error',
      responseBody: error,
    );
  }

  /// Close the HTTP client
  void close() {
    _httpClient.close();
  }
}
