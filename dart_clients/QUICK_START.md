# CL Server Dart Client - Quick Start Guide

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  cl_server:
    path: packages/cl_server
```

Then run:
```bash
dart pub get
```

## Basic Usage

### Login and Get User Info

```dart
import 'package:cl_server/cl_server.dart';

void main() async {
  final client = AuthClient(baseUrl: 'http://localhost:8000');

  try {
    // Login
    final token = await client.login('admin', 'admin');
    print('Token: ${token.accessToken}');

    // Get current user
    final user = await client.getCurrentUser(token.accessToken);
    print('User: ${user.username} (Admin: ${user.isAdmin})');

  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
```

### Token Parsing

```dart
final tokenData = client.parseToken(token.accessToken);

print('User ID: ${tokenData.userId}');
print('Permissions: ${tokenData.permissions}');
print('Is Admin: ${tokenData.isAdmin}');
print('Expires: ${tokenData.expiresAt}');
print('Is Expired: ${tokenData.isExpired}');

// Check permission
if (tokenData.hasPermission('read')) {
  print('User has read permission');
}
```

### User Management (Admin Only)

```dart
final token = await client.login('admin', 'admin');

// Create user
final newUser = await client.createUser(
  token: token.accessToken,
  username: 'john',
  password: 'secure_pass',
  permissions: ['read', 'write'],
);

// List users
final users = await client.listUsers(
  token: token.accessToken,
  skip: 0,
  limit: 10,
);

// Get user
final user = await client.getUser(
  token: token.accessToken,
  userId: 5,
);

// Update user
final updated = await client.updateUser(
  token: token.accessToken,
  userId: 5,
  isAdmin: true,
  permissions: ['read', 'write', 'delete'],
);

// Delete user
await client.deleteUser(
  token: token.accessToken,
  userId: 5,
);
```

### Error Handling

```dart
import 'package:cl_server/cl_server.dart';

try {
  await client.login('admin', 'wrong_password');
} on AuthenticationException catch (e) {
  print('Login failed: ${e.message}');
} on ValidationException catch (e) {
  print('Validation error: ${e.message}');
} on NotFoundException catch (e) {
  print('Not found: ${e.message}');
} on ServerException catch (e) {
  print('Server error: ${e.statusCode} - ${e.message}');
} on CLServerException catch (e) {
  print('Error: ${e.message}');
}
```

### Token Persistence (App Responsibility)

```dart
import 'dart:io';

// Save token to file
final token = await client.login('admin', 'admin');
await File('token.txt').writeAsString(token.accessToken);

// Load token from file
final savedToken = await File('token.txt').readAsString();
final user = await client.getCurrentUser(savedToken);
```

## Command Line Example

Run the interactive CLI:

```bash
cd dart_clients/packages/cl_server
dart run example/cli_app.dart
```

Then use commands:

```
cl_server> login admin admin
cl_server> whoami
cl_server> users list
cl_server> users create newuser password123 --perms read,write
cl_server> logout
cl_server> exit
```

## Running Tests

```bash
cd dart_clients/packages/cl_server

# Run all tests
dart test test/integration/

# Run specific test file
dart test test/integration/auth_login_test.dart

# Watch mode
dart test --watch test/integration/
```

## API Reference

### AuthClient

#### Authentication
- `Future<Token> login(String username, String password)`
- `Future<User> getCurrentUser(String token)`
- `TokenData parseToken(String token)`
- `bool isTokenExpired(String token)`
- `TokenData? tryParseToken(String token)`

#### User Management (Admin)
- `Future<User> createUser({required String token, ...})`
- `Future<List<User>> listUsers({required String token, ...})`
- `Future<User> getUser({required String token, required int userId})`
- `Future<User> updateUser({required String token, ...})`
- `Future<void> deleteUser({required String token, required int userId})`

#### Public Key
- `Future<String> getPublicKey()`
- `void clearPublicKeyCache()`

### TokenData

Properties:
- `String userId` - User ID
- `List<String> permissions` - User permissions
- `bool isAdmin` - Admin flag
- `DateTime expiresAt` - Expiration time
- `bool isExpired` - Check if expired
- `Duration remainingDuration` - Time until expiration

Methods:
- `bool hasPermission(String permission)` - Check if user has permission

### User

Properties:
- `int id` - User ID
- `String username` - Username
- `bool isAdmin` - Admin flag
- `bool isActive` - Active flag
- `DateTime createdAt` - Creation time
- `List<String> permissions` - User permissions

### Token

Properties:
- `String accessToken` - JWT token string
- `String tokenType` - Token type (usually "bearer")

## Exception Types

- `CLServerException` - Base exception
- `AuthenticationException` - 401 errors
- `AuthorizationException` - 403 errors
- `NotFoundException` - 404 errors
- `ValidationException` - 400 errors
- `DuplicateResourceException` - 409 errors
- `ServerException` - 5xx errors

## Next Steps

- Read the full [README.md](packages/cl_server/README.md)
- Check the [Implementation Summary](IMPLEMENTATION_SUMMARY.md)
- Explore the [example CLI app](packages/cl_server/example/cli_app.dart)
- Run the [integration tests](packages/cl_server/test/integration/)
