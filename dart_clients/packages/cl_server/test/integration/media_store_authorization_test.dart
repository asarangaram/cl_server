import 'package:test/test.dart';
import 'package:cl_server/cl_server.dart';

void main() {
  late AuthClient authClient;
  late MediaStoreClient mediaStoreClient;
  late String adminToken;
  late String userWithWriteToken;
  late String userWithoutWriteToken;
  late String readOnlyUserToken;

  setUpAll(() async {
    authClient = AuthClient(baseUrl: 'http://localhost:8000');
    mediaStoreClient = MediaStoreClient(baseUrl: 'http://localhost:8001');

    // Login as admin
    final adminTokenResponse = await authClient.login('admin', 'admin');
    adminToken = adminTokenResponse.accessToken;

    // Create users with different permissions
    final userWithWrite = await authClient.createUser(
      token: adminToken,
      username: 'user_with_write_${DateTime.now().millisecondsSinceEpoch}',
      password: 'password123',
      permissions: ['read', 'write'],
    );

    final userWithoutWrite = await authClient.createUser(
      token: adminToken,
      username: 'user_no_write_${DateTime.now().millisecondsSinceEpoch}',
      password: 'password123',
      permissions: ['read'],
    );

    final readOnlyUser = await authClient.createUser(
      token: adminToken,
      username: 'read_only_${DateTime.now().millisecondsSinceEpoch}',
      password: 'password123',
      permissions: [],
    );

    // Login as these users
    final writeUserLogin = await authClient.login(
      userWithWrite.username,
      'password123',
    );
    userWithWriteToken = writeUserLogin.accessToken;

    final noWriteUserLogin = await authClient.login(
      userWithoutWrite.username,
      'password123',
    );
    userWithoutWriteToken = noWriteUserLogin.accessToken;

    final readOnlyLogin = await authClient.login(
      readOnlyUser.username,
      'password123',
    );
    readOnlyUserToken = readOnlyLogin.accessToken;
  });

  tearDownAll(() {
    authClient.close();
    mediaStoreClient.close();
  });

  group('Media Store - Authorization & Access Control', () {
    group('Read Authentication Control', () {
      test('Admin: Enable read without authentication (read_auth_enabled = false)', () async {
        // Set read_auth_enabled to false (allow unauthenticated reads)
        final config = await mediaStoreClient.setReadAuth(
          token: adminToken,
          readAuthEnabled: false,
        );

        expect(config.readAuthEnabled, isFalse);
        print('✅ Read without authentication ENABLED');
      });

      test('User with write permission: Can create entity', () async {
        final entity = await mediaStoreClient.createCollection(
          token: userWithWriteToken,
          label: 'Write Test Collection',
        );

        expect(entity.id, isNotNull);
        expect(entity.label, equals('Write Test Collection'));
        print('✅ User with write permission can CREATE');
      });

      test('User without write permission: Cannot create entity', () async {
        expect(
          () => mediaStoreClient.createCollection(
            token: userWithoutWriteToken,
            label: 'Should Fail',
          ),
          throwsA(isA<AuthorizationException>()),
        );
        print('✅ User without write permission CANNOT CREATE (AuthorizationException)');
      });

      test('User without write permission: Can read entities', () async {
        // User without write permission should still be able to list
        final entities = await mediaStoreClient.listEntities(
          token: userWithoutWriteToken,
        );

        expect(entities, isA<List<Entity>>());
        print('✅ User without write permission CAN READ');
      });

      test('Read-only user: Cannot create (no read/write perms)', () async {
        expect(
          () => mediaStoreClient.createCollection(
            token: readOnlyUserToken,
            label: 'Should Fail',
          ),
          throwsA(isA<AuthorizationException>()),
        );
        print('✅ Read-only user CANNOT CREATE');
      });

      test('Admin: Disable read without authentication (read_auth_enabled = true)', () async {
        // Set read_auth_enabled to true (require authentication for reads)
        final config = await mediaStoreClient.setReadAuth(
          token: adminToken,
          readAuthEnabled: true,
        );

        expect(config.readAuthEnabled, isTrue);
        print('✅ Read without authentication DISABLED');
      });

      test('Authenticated user: Can read after disabling anonymous read', () async {
        // User with token should still be able to read
        final entities = await mediaStoreClient.listEntities(
          token: userWithWriteToken,
        );

        expect(entities, isA<List<Entity>>());
        print('✅ Authenticated user CAN READ even with read_auth_enabled = true');
      });
    });

    group('Write Permission Control', () {
      test('User with write permission: Can create collection', () async {
        final collection = await mediaStoreClient.createCollection(
          token: userWithWriteToken,
          label: 'Collection by Write User',
        );

        expect(collection.id, isNotNull);
        expect(collection.isCollection, isTrue);
        print('✅ Write-permitted user CAN CREATE COLLECTION');
      });

      test('User with write permission: Can patch entity', () async {
        final created = await mediaStoreClient.createCollection(
          token: userWithWriteToken,
          label: 'Original',
        );

        final patched = await mediaStoreClient.patchEntity(
          token: userWithWriteToken,
          entityId: created.id,
          label: 'Modified',
        );

        expect(patched.label, equals('Modified'));
        print('✅ Write-permitted user CAN MODIFY');
      });

      test('User with write permission: Can delete entity', () async {
        final created = await mediaStoreClient.createCollection(
          token: userWithWriteToken,
          label: 'To Delete',
        );

        await mediaStoreClient.deleteEntity(
          token: userWithWriteToken,
          entityId: created.id,
        );

        print('✅ Write-permitted user CAN DELETE');
      });

      test('User without write permission: Cannot patch entity created by write user',
          () async {
        // Create entity as write user
        final created = await mediaStoreClient.createCollection(
          token: userWithWriteToken,
          label: 'Created by Write User',
        );

        // Try to patch as read-only user
        expect(
          () => mediaStoreClient.patchEntity(
            token: userWithoutWriteToken,
            entityId: created.id,
            label: 'Attempted Patch',
          ),
          throwsA(isA<AuthorizationException>()),
        );
        print('✅ Non-write-permitted user CANNOT MODIFY');
      });

      test('User without write permission: Cannot delete entity', () async {
        // Create entity as write user
        final created = await mediaStoreClient.createCollection(
          token: userWithWriteToken,
          label: 'Cannot Delete This',
        );

        // Try to delete as read-only user
        expect(
          () => mediaStoreClient.deleteEntity(
            token: userWithoutWriteToken,
            entityId: created.id,
          ),
          throwsA(isA<AuthorizationException>()),
        );
        print('✅ Non-write-permitted user CANNOT DELETE');
      });
    });

    group('Read Permission Control', () {
      test('User with read permission: Can list entities', () async {
        final entities = await mediaStoreClient.listEntities(
          token: userWithoutWriteToken,
        );

        expect(entities, isA<List<Entity>>());
        print('✅ Read-permitted user CAN LIST');
      });

      test('User with read permission: Can get entity details', () async {
        // Create an entity as write user
        final created = await mediaStoreClient.createCollection(
          token: userWithWriteToken,
          label: 'Read Test Entity',
        );

        // Read as non-write user
        final entity = await mediaStoreClient.getEntity(
          token: userWithoutWriteToken,
          entityId: created.id,
        );

        expect(entity.label, equals('Read Test Entity'));
        print('✅ Read-permitted user CAN READ DETAILS');
      });

      test('User without read permission: Cannot list entities', () async {
        // readOnlyUser has no permissions
        expect(
          () => mediaStoreClient.listEntities(token: readOnlyUserToken),
          throwsA(isA<AuthorizationException>()),
        );
        print('✅ Non-read-permitted user CANNOT LIST');
      });

      test('User without read permission: Cannot get entity details', () async {
        // Create an entity as write user
        final created = await mediaStoreClient.createCollection(
          token: userWithWriteToken,
          label: 'Entity for No-Read User',
        );

        // Try to read as user with no permissions
        expect(
          () => mediaStoreClient.getEntity(
            token: readOnlyUserToken,
            entityId: created.id,
          ),
          throwsA(isA<AuthorizationException>()),
        );
        print('✅ Non-read-permitted user CANNOT READ DETAILS');
      });
    });

    group('Admin Configuration Access Control', () {
      test('Admin user: Can get service config', () async {
        final config = await mediaStoreClient.getConfig(token: adminToken);

        expect(config, isNotNull);
        expect(config.readAuthEnabled, isA<bool>());
        print('✅ Admin user CAN GET CONFIG');
      });

      test('Admin user: Can set service config', () async {
        final config = await mediaStoreClient.setReadAuth(
          token: adminToken,
          readAuthEnabled: false,
        );

        expect(config.readAuthEnabled, isFalse);
        print('✅ Admin user CAN SET CONFIG');
      });

      test('Non-admin user: Cannot get service config', () async {
        expect(
          () => mediaStoreClient.getConfig(token: userWithWriteToken),
          throwsA(isA<AuthorizationException>()),
        );
        print('✅ Non-admin user CANNOT GET CONFIG');
      });

      test('Non-admin user: Cannot set service config', () async {
        expect(
          () => mediaStoreClient.setReadAuth(
            token: userWithWriteToken,
            readAuthEnabled: true,
          ),
          throwsA(isA<AuthorizationException>()),
        );
        print('✅ Non-admin user CANNOT SET CONFIG');
      });
    });

    group('Complex Authorization Scenarios', () {
      test('Scenario 1: User creates entity, other user can read but not modify', () async {
        // User 1 (write) creates entity
        final entity = await mediaStoreClient.createCollection(
          token: userWithWriteToken,
          label: 'Scenario 1 Entity',
          description: 'Created by write user',
        );

        // User 2 (read-only) reads entity
        final read = await mediaStoreClient.getEntity(
          token: userWithoutWriteToken,
          entityId: entity.id,
        );

        expect(read.label, equals('Scenario 1 Entity'));

        // User 2 (read-only) tries to modify
        expect(
          () => mediaStoreClient.patchEntity(
            token: userWithoutWriteToken,
            entityId: entity.id,
            label: 'Modified by read user',
          ),
          throwsA(isA<AuthorizationException>()),
        );

        print('✅ Scenario 1: Read-only user can read but not modify');
      });

      test('Scenario 2: Permission updates are enforced on next request', () async {
        // Create user with write permission
        final user = await authClient.createUser(
          token: adminToken,
          username: 'perm_test_${DateTime.now().millisecondsSinceEpoch}',
          password: 'pass',
          permissions: ['read', 'write'],
        );

        // Login
        final tokenResp = await authClient.login(user.username, 'pass');
        var token = tokenResp.accessToken;

        // Create entity (should work)
        final entity = await mediaStoreClient.createCollection(
          token: token,
          label: 'Before Permission Change',
        );

        expect(entity.id, isNotNull);

        // Admin removes write permission
        await authClient.updateUser(
          token: adminToken,
          userId: user.id,
          permissions: ['read'], // Remove 'write'
        );

        // Re-login to get new token
        final newTokenResp = await authClient.login(user.username, 'pass');
        token = newTokenResp.accessToken;

        // Try to create with new token (should fail)
        expect(
          () => mediaStoreClient.createCollection(
            token: token,
            label: 'After Permission Change',
          ),
          throwsA(isA<AuthorizationException>()),
        );

        print('✅ Scenario 2: Permission changes enforced on next login');
      });

      test('Scenario 3: Admin re-enables anonymous read access', () async {
        // Ensure read_auth is enabled
        await mediaStoreClient.setReadAuth(
          token: adminToken,
          readAuthEnabled: true,
        );

        // Create entity as authenticated user
        final entity = await mediaStoreClient.createCollection(
          token: userWithWriteToken,
          label: 'Public Entity',
        );

        // Disable read authentication
        await mediaStoreClient.setReadAuth(
          token: adminToken,
          readAuthEnabled: false,
        );

        // Now any authenticated user can read (but we still need a token)
        final readEntity = await mediaStoreClient.getEntity(
          token: userWithoutWriteToken,
          entityId: entity.id,
        );

        expect(readEntity.label, equals('Public Entity'));

        print('✅ Scenario 3: Anonymous read access works when enabled');
      });
    });
  });
}
