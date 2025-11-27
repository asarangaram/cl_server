/// Base exception class for CL Server errors
class CLServerException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic responseBody;

  CLServerException({
    required this.message,
    this.statusCode,
    this.responseBody,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return 'CLServerException($statusCode): $message';
    }
    return 'CLServerException: $message';
  }
}

/// Exception thrown when authentication fails (401)
class AuthenticationException extends CLServerException {
  AuthenticationException({
    required String message,
    int? statusCode = 401,
    dynamic responseBody,
  }) : super(
    message: message,
    statusCode: statusCode,
    responseBody: responseBody,
  );
}

/// Exception thrown when authorization fails (403)
class AuthorizationException extends CLServerException {
  AuthorizationException({
    required String message,
    int? statusCode = 403,
    dynamic responseBody,
  }) : super(
    message: message,
    statusCode: statusCode,
    responseBody: responseBody,
  );
}

/// Exception thrown when resource is not found (404)
class NotFoundException extends CLServerException {
  NotFoundException({
    required String message,
    int? statusCode = 404,
    dynamic responseBody,
  }) : super(
    message: message,
    statusCode: statusCode,
    responseBody: responseBody,
  );
}

/// Exception thrown when request validation fails (400)
class ValidationException extends CLServerException {
  ValidationException({
    required String message,
    int? statusCode = 400,
    dynamic responseBody,
  }) : super(
    message: message,
    statusCode: statusCode,
    responseBody: responseBody,
  );
}

/// Exception thrown when resource already exists (409)
class DuplicateResourceException extends CLServerException {
  DuplicateResourceException({
    required String message,
    int? statusCode = 409,
    dynamic responseBody,
  }) : super(
    message: message,
    statusCode: statusCode,
    responseBody: responseBody,
  );
}

/// Exception thrown for server errors (5xx)
class ServerException extends CLServerException {
  ServerException({
    required String message,
    required int statusCode,
    dynamic responseBody,
  }) : super(
    message: message,
    statusCode: statusCode,
    responseBody: responseBody,
  );
}
