import 'package:test/test.dart';
import 'package:cl_server/cl_server.dart';

void main() {
  late AuthClient client;
  late String adminToken;
  late List<int> createdUserIds;

  setUpAll(() async {
    client = AuthClient(baseUrl: 'http://localhost:8000');

    // Login as admin
    final token = await client.login('admin', 'admin');
    adminToken = token.accessToken;

    createdUserIds = [];
  });

  tearDownAll(() {
    client.close();
  });

  setUp(() {
    createdUserIds = [];
  });

  tearDown(() async {
    // Clean up created users
    for (final userId in createdUserIds) {
      try {
        await client.deleteUser(token: adminToken, userId: userId);
      } catch (e) {
        // Ignore errors during cleanup
      }
    }
  });

  group('Authentication - Permission Management', () {
    test('Create user with specific permissions', () async {
      final user = await client.createUser(
        token: adminToken,
        username: 'user_read_only_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
        permissions: ['media_store_read'],
      );

      expect(user.permissions, equals(['media_store_read']));
      createdUserIds.add(user.id);
    });

    test('Create user with multiple permissions', () async {
      final user = await client.createUser(
        token: adminToken,
        username: 'user_full_access_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
        permissions: ['media_store_read', 'media_store_write', 'inference_submit'],
      );

      expect(user.permissions, containsAll(['media_store_read', 'media_store_write', 'inference_submit']));
      createdUserIds.add(user.id);
    });

    test('Token contains user permissions', () async {
      // Create user with specific permissions
      final user = await client.createUser(
        token: adminToken,
        username: 'token_perms_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
        permissions: ['read', 'write'],
      );
      createdUserIds.add(user.id);

      // Login as that user
      final userToken = await client.login(user.username, 'password123');

      // Parse token and check permissions
      final tokenData = client.parseToken(userToken.accessToken);
      expect(tokenData.permissions, containsAll(['read', 'write']));
      expect(tokenData.isAdmin, isFalse);
    });

    test('Admin user has all permissions', () async {
      // Create admin user
      final user = await client.createUser(
        token: adminToken,
        username: 'admin_user_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
        isAdmin: true,
      );
      createdUserIds.add(user.id);

      // Login as admin user
      final userToken = await client.login(user.username, 'password123');

      // Parse token
      final tokenData = client.parseToken(userToken.accessToken);
      expect(tokenData.isAdmin, isTrue);

      // Check hasPermission works for admin
      expect(tokenData.hasPermission('any_permission'), isTrue);
      expect(tokenData.hasPermission('another_permission'), isTrue);
    });

    test('Non-admin user has specific permissions only', () async {
      // Create non-admin user with specific permissions
      final user = await client.createUser(
        token: adminToken,
        username: 'restricted_user_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
        isAdmin: false,
        permissions: ['read'],
      );
      createdUserIds.add(user.id);

      // Login as that user
      final userToken = await client.login(user.username, 'password123');

      // Parse token
      final tokenData = client.parseToken(userToken.accessToken);
      expect(tokenData.isAdmin, isFalse);
      expect(tokenData.hasPermission('read'), isTrue);
      expect(tokenData.hasPermission('write'), isFalse);
    });

    test('Update user to grant new permissions', () async {
      // Create user with no permissions
      var user = await client.createUser(
        token: adminToken,
        username: 'grant_perms_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
        permissions: [],
      );
      createdUserIds.add(user.id);

      expect(user.permissions, isEmpty);

      // Grant permissions
      user = await client.updateUser(
        token: adminToken,
        userId: user.id,
        permissions: ['media_store_read', 'media_store_write'],
      );

      expect(user.permissions, containsAll(['media_store_read', 'media_store_write']));
    });

    test('Update user to revoke permissions', () async {
      // Create user with permissions
      var user = await client.createUser(
        token: adminToken,
        username: 'revoke_perms_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
        permissions: ['read', 'write', 'delete'],
      );
      createdUserIds.add(user.id);

      expect(user.permissions, containsAll(['read', 'write', 'delete']));

      // Revoke all permissions
      user = await client.updateUser(
        token: adminToken,
        userId: user.id,
        permissions: [],
      );

      expect(user.permissions, isEmpty);
    });

    test('Update user to grant admin privilege', () async {
      // Create non-admin user
      var user = await client.createUser(
        token: adminToken,
        username: 'grant_admin_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
        isAdmin: false,
      );
      createdUserIds.add(user.id);

      expect(user.isAdmin, isFalse);

      // Grant admin privilege
      user = await client.updateUser(
        token: adminToken,
        userId: user.id,
        isAdmin: true,
      );

      expect(user.isAdmin, isTrue);

      // Verify token shows admin status
      final userToken = await client.login(user.username, 'password123');
      final tokenData = client.parseToken(userToken.accessToken);
      expect(tokenData.isAdmin, isTrue);
    });

    test('Update user to revoke admin privilege', () async {
      // Create admin user
      var user = await client.createUser(
        token: adminToken,
        username: 'revoke_admin_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
        isAdmin: true,
      );
      createdUserIds.add(user.id);

      expect(user.isAdmin, isTrue);

      // Revoke admin privilege
      user = await client.updateUser(
        token: adminToken,
        userId: user.id,
        isAdmin: false,
      );

      expect(user.isAdmin, isFalse);
    });

    test('Permission helper hasPermission works correctly', () async {
      // Create user with mixed permissions
      final user = await client.createUser(
        token: adminToken,
        username: 'perm_helper_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
        permissions: ['read', 'list'],
      );
      createdUserIds.add(user.id);

      // Login and parse token
      final userToken = await client.login(user.username, 'password123');
      final tokenData = client.parseToken(userToken.accessToken);

      // Test hasPermission
      expect(tokenData.hasPermission('read'), isTrue);
      expect(tokenData.hasPermission('list'), isTrue);
      expect(tokenData.hasPermission('write'), isFalse);
      expect(tokenData.hasPermission('delete'), isFalse);
    });

    test('Admin user can access user management endpoints', () async {
      // Admin should be able to list users
      final users = await client.listUsers(token: adminToken);
      expect(users, isNotEmpty);

      // Admin should be able to create user
      final newUser = await client.createUser(
        token: adminToken,
        username: 'admin_can_create_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
      );
      expect(newUser.id, isNotNull);
      createdUserIds.add(newUser.id);

      // Admin should be able to get user
      final user = await client.getUser(token: adminToken, userId: newUser.id);
      expect(user.id, equals(newUser.id));
    });

    test('Changing permissions updates token on re-login', () async {
      // Create user with one permission
      var user = await client.createUser(
        token: adminToken,
        username: 'perm_change_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
        permissions: ['read'],
      );
      createdUserIds.add(user.id);

      // Login and check token
      var token1 = await client.login(user.username, 'password123');
      var tokenData1 = client.parseToken(token1.accessToken);
      expect(tokenData1.permissions, equals(['read']));

      // Update permissions
      await client.updateUser(
        token: adminToken,
        userId: user.id,
        permissions: ['read', 'write'],
      );

      // Login again and check updated token
      var token2 = await client.login(user.username, 'password123');
      var tokenData2 = client.parseToken(token2.accessToken);
      expect(tokenData2.permissions, containsAll(['read', 'write']));
    });
  });
}
