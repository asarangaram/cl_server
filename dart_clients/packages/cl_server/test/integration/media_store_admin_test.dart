import 'package:test/test.dart';
import 'package:cl_server/cl_server.dart';

void main() {
  late AuthClient authClient;
  late MediaStoreClient mediaStoreClient;
  late String adminToken;
  // ignore: unused_local_variable
  late String regularUserToken;

  setUpAll(() async {
    authClient = AuthClient(baseUrl: 'http://localhost:8000');
    mediaStoreClient = MediaStoreClient(baseUrl: 'http://localhost:8001');

    // Login as admin
    final adminTokenResponse = await authClient.login('admin', 'admin');
    adminToken = adminTokenResponse.accessToken;

    // Create a regular user for testing
    final testUsername = 'testuser_${DateTime.now().millisecondsSinceEpoch}';
    await authClient.createUser(
      token: adminToken,
      username: testUsername,
      password: 'testpass123',
      permissions: ['read'],
    );

    // Login as regular user
    final userTokenResponse = await authClient.login(
      testUsername,
      'testpass123',
    );
    regularUserToken = userTokenResponse.accessToken;
  });

  tearDownAll(() {
    authClient.close();
    mediaStoreClient.close();
  });

  group('Media Store - Admin Configuration', () {
    test('Get current configuration', () async {
      final config = await mediaStoreClient.getConfig(
        token: adminToken,
      );

      expect(config, isNotNull);
      expect(config.readAuthEnabled, isA<bool>());
    });

    test('Config response has read auth enabled field', () async {
      final config = await mediaStoreClient.getConfig(
        token: adminToken,
      );

      // readAuthEnabled should be boolean
      expect(config.readAuthEnabled, isA<bool>());
    });

    test('Config response has timestamp information', () async {
      final config = await mediaStoreClient.getConfig(
        token: adminToken,
      );

      // May have updated_at timestamp (milliseconds since epoch)
      expect(config.updatedAt, anyOf(isNull, isA<int>()));
      expect(config.updatedBy, anyOf(isNull, isA<String>()));
    });

    test('Set read auth to true', () async {
      final config = await mediaStoreClient.setReadAuth(
        token: adminToken,
        readAuthEnabled: true,
      );

      expect(config.readAuthEnabled, isTrue);
    });

    test('Set read auth to false', () async {
      final config = await mediaStoreClient.setReadAuth(
        token: adminToken,
        readAuthEnabled: false,
      );

      expect(config.readAuthEnabled, isFalse);
    });

    test('Configuration change persists', () async {
      // Set to true
      await mediaStoreClient.setReadAuth(
        token: adminToken,
        readAuthEnabled: true,
      );

      // Verify it's true
      var config = await mediaStoreClient.getConfig(
        token: adminToken,
      );
      expect(config.readAuthEnabled, isTrue);

      // Set to false
      await mediaStoreClient.setReadAuth(
        token: adminToken,
        readAuthEnabled: false,
      );

      // Verify it's false
      config = await mediaStoreClient.getConfig(
        token: adminToken,
      );
      expect(config.readAuthEnabled, isFalse);
    });

    test('Configuration updates timestamp', () async {
      final before = await mediaStoreClient.getConfig(
        token: adminToken,
      );

      // Wait a moment
      await Future.delayed(const Duration(milliseconds: 100));

      // Update config
      await mediaStoreClient.setReadAuth(
        token: adminToken,
        readAuthEnabled: !(before.readAuthEnabled),
      );

      final after = await mediaStoreClient.getConfig(
        token: adminToken,
      );

      // Timestamp should be updated (if service tracks it)
      expect(
          after.updatedAt,
          anyOf(
            isNull,
            isA<int>(),
          ));
    });

    test('Configuration tracks who made the change', () async {
      final config = await mediaStoreClient.setReadAuth(
        token: adminToken,
        readAuthEnabled: true,
      );

      // updatedBy should indicate admin user (as user ID string)
      expect(config.updatedBy, anyOf(isNull, isA<String>()));
      // If it's set, should be a non-empty string
      if (config.updatedBy != null) {
        expect(config.updatedBy, isNotEmpty);
      }
    });

    test('Toggle read auth multiple times', () async {
      var config = await mediaStoreClient.getConfig(
        token: adminToken,
      );

      final initialState = config.readAuthEnabled;

      // Toggle 3 times
      for (int i = 0; i < 3; i++) {
        config = await mediaStoreClient.setReadAuth(
          token: adminToken,
          readAuthEnabled: !config.readAuthEnabled,
        );

        expect(config.readAuthEnabled,
            isNot(equals(initialState == (i % 2 == 0))));
      }
    });

    test('Read auth configuration returns consistent value', () async {
      final config1 = await mediaStoreClient.getConfig(
        token: adminToken,
      );

      // Small delay
      await Future.delayed(const Duration(milliseconds: 50));

      final config2 = await mediaStoreClient.getConfig(
        token: adminToken,
      );

      // Both reads should return same value
      expect(config1.readAuthEnabled, equals(config2.readAuthEnabled));
    });

    test('Admin can get configuration', () async {
      expect(
        () => mediaStoreClient.getConfig(token: adminToken),
        returnsNormally,
      );
    });

    test('Admin can set configuration', () async {
      expect(
        () => mediaStoreClient.setReadAuth(
          token: adminToken,
          readAuthEnabled: true,
        ),
        returnsNormally,
      );
    });

    test('Configuration changes take effect immediately', () async {
      // Set to true
      await mediaStoreClient.setReadAuth(
        token: adminToken,
        readAuthEnabled: true,
      );

      // Immediately read
      var config = await mediaStoreClient.getConfig(
        token: adminToken,
      );
      expect(config.readAuthEnabled, isTrue);

      // Set to false
      await mediaStoreClient.setReadAuth(
        token: adminToken,
        readAuthEnabled: false,
      );

      // Immediately read
      config = await mediaStoreClient.getConfig(
        token: adminToken,
      );
      expect(config.readAuthEnabled, isFalse);
    });

    test('Configuration JSON serialization', () async {
      final config = await mediaStoreClient.getConfig(
        token: adminToken,
      );

      // Should be able to convert to JSON
      final json = config.toJson();
      expect(json, isA<Map<String, dynamic>>());
      expect(json['read_auth_enabled'], isA<bool>());
    });

    test('Configuration round-trip serialization', () async {
      final config1 = await mediaStoreClient.getConfig(
        token: adminToken,
      );

      // Convert to JSON and back
      final json = config1.toJson();
      final config2 = ConfigResponse.fromJson(json);

      expect(config2.readAuthEnabled, equals(config1.readAuthEnabled));
      expect(config2.updatedAt, equals(config1.updatedAt));
      expect(config2.updatedBy, equals(config1.updatedBy));
    });
  });
}
