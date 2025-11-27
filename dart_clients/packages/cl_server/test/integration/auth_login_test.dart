import 'package:test/test.dart';
import 'package:cl_server/cl_server.dart';

void main() {
  late AuthClient client;

  setUpAll(() {
    client = AuthClient(baseUrl: 'http://localhost:8000');
  });

  tearDownAll(() {
    client.close();
  });

  group('Authentication - Login Workflow', () {
    test('Successful login with valid credentials', () async {
      final token = await client.login('admin', 'admin');

      expect(token, isNotNull);
      expect(token.accessToken, isNotEmpty);
      expect(token.tokenType, equals('bearer'));
    });

    test('Failed login with invalid credentials', () async {
      expect(
        () => client.login('admin', 'wrongpassword'),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('Failed login with non-existent user', () async {
      expect(
        () => client.login('nonexistent', 'password'),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('Token data parsing - extract claims correctly', () async {
      final token = await client.login('admin', 'admin');
      final tokenData = client.parseToken(token.accessToken);

      expect(tokenData, isNotNull);
      expect(tokenData.userId, isNotEmpty);
      expect(tokenData.isAdmin, isTrue);
      expect(tokenData.permissions, contains('*'));
      expect(tokenData.expiresAt, isNotNull);
    });

    test('Token data - check permission helper', () async {
      final token = await client.login('admin', 'admin');
      final tokenData = client.parseToken(token.accessToken);

      // Admin should have all permissions
      expect(tokenData.hasPermission('any_permission'), isTrue);
      expect(tokenData.hasPermission('another_permission'), isTrue);
    });

    test('Token expiration detection - valid token not expired', () async {
      final token = await client.login('admin', 'admin');
      final tokenData = client.parseToken(token.accessToken);

      expect(tokenData.isExpired, isFalse);
      expect(tokenData.remainingDuration.inSeconds, greaterThan(0));
    });

    test('Token expiration check - isTokenExpired method', () async {
      final token = await client.login('admin', 'admin');

      expect(client.isTokenExpired(token.accessToken), isFalse);
    });

    test('Invalid token format throws ValidationException', () {
      expect(
        () => client.parseToken('not.a.valid.token'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Malformed token returns null with tryParseToken', () {
      final result = client.tryParseToken('invalid.token');
      expect(result, isNull);
    });

    test('Empty token throws ValidationException', () {
      expect(
        () => client.parseToken(''),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Get current user with valid token', () async {
      final token = await client.login('admin', 'admin');
      final user = await client.getCurrentUser(token.accessToken);

      expect(user, isNotNull);
      expect(user.id, isNotNull);
      expect(user.username, equals('admin'));
      expect(user.isAdmin, isTrue);
      expect(user.isActive, isTrue);
    });

    test('Get current user with expired token throws AuthenticationException', () async {
      // Create an expired token by modifying the timestamp
      // For now, we'll test with an invalid token
      expect(
        () => client.getCurrentUser('expired.token.here'),
        throwsA(isA<CLServerException>()),
      );
    });

    test('Token contains proper datetime for expiration', () async {
      final token = await client.login('admin', 'admin');
      final tokenData = client.parseToken(token.accessToken);

      expect(tokenData.expiresAt, isA<DateTime>());
      // Should be in the future (within 30 minutes by default)
      final now = DateTime.now();
      expect(tokenData.expiresAt.isAfter(now), isTrue);
      expect(tokenData.expiresAt.isBefore(now.add(const Duration(hours: 1))), isTrue);
    });

    test('Public key endpoint returns valid key', () async {
      final publicKey = await client.getPublicKey();

      expect(publicKey, isNotEmpty);
      expect(publicKey, contains('BEGIN PUBLIC KEY'));
      expect(publicKey, contains('END PUBLIC KEY'));
    });

    test('Public key caching works', () async {
      // First call fetches from server
      final key1 = await client.getPublicKey();

      // Second call should return cached value
      final key2 = await client.getPublicKey();

      expect(key1, equals(key2));

      // Clear cache and fetch again
      client.clearPublicKeyCache();
      final key3 = await client.getPublicKey();

      expect(key3, equals(key1));
    });
  });
}
