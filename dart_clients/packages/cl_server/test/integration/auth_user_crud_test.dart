import 'package:test/test.dart';
import 'package:cl_server/cl_server.dart';

void main() {
  late AuthClient client;
  late String adminToken;
  late int createdUserId;

  setUpAll(() async {
    client = AuthClient(baseUrl: 'http://localhost:8000');

    // Login as admin for all tests
    final token = await client.login('admin', 'admin');
    adminToken = token.accessToken;
  });

  tearDownAll(() {
    client.close();
  });

  setUp(() {
    createdUserId = -1;
  });

  tearDown(() async {
    // Clean up created users
    if (createdUserId != -1) {
      try {
        await client.deleteUser(token: adminToken, userId: createdUserId);
      } catch (e) {
        // Ignore errors during cleanup
      }
    }
  });

  group('Authentication - User CRUD Operations', () {
    test('Create new user with basic info', () async {
      final user = await client.createUser(
        token: adminToken,
        username: 'testuser_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
        isAdmin: false,
        isActive: true,
      );

      expect(user, isNotNull);
      expect(user.id, isNotNull);
      expect(user.username, isNotEmpty);
      expect(user.isAdmin, isFalse);
      expect(user.isActive, isTrue);
      expect(user.createdAt, isNotNull);

      createdUserId = user.id;
    });

    test('Create user with admin privileges', () async {
      final user = await client.createUser(
        token: adminToken,
        username: 'admin_test_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
        isAdmin: true,
      );

      expect(user.isAdmin, isTrue);
      createdUserId = user.id;
    });

    test('Create user with permissions', () async {
      final user = await client.createUser(
        token: adminToken,
        username: 'user_with_perms_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
        permissions: ['read', 'write'],
      );

      expect(user.permissions, containsAll(['read', 'write']));
      createdUserId = user.id;
    });

    test('Create user with duplicate username throws ValidationException', () async {
      final username = 'duplicate_test_${DateTime.now().millisecondsSinceEpoch}';

      // Create first user
      var user1 = await client.createUser(
        token: adminToken,
        username: username,
        password: 'password1',
      );
      createdUserId = user1.id;

      // Try to create second user with same username
      expect(
        () => client.createUser(
          token: adminToken,
          username: username,
          password: 'password2',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('List users returns list of users', () async {
      final users = await client.listUsers(token: adminToken);

      expect(users, isNotEmpty);
      expect(users, isA<List<User>>());

      // Should at least have admin user
      final adminUser = users.firstWhere((u) => u.username == 'admin');
      expect(adminUser.isAdmin, isTrue);
    });

    test('List users pagination works', () async {
      final allUsers = await client.listUsers(token: adminToken);
      final firstPage = await client.listUsers(token: adminToken, skip: 0, limit: 1);

      expect(firstPage.length, equals(1));
      expect(firstPage[0].id, equals(allUsers[0].id));
    });

    test('Get specific user by ID', () async {
      // Create a user
      final createdUser = await client.createUser(
        token: adminToken,
        username: 'get_user_test_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
      );
      createdUserId = createdUser.id;

      // Get the user
      final user = await client.getUser(token: adminToken, userId: createdUserId);

      expect(user.id, equals(createdUser.id));
      expect(user.username, equals(createdUser.username));
    });

    test('Get non-existent user throws NotFoundException', () async {
      expect(
        () => client.getUser(token: adminToken, userId: 999999),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('Update user password', () async {
      // Create a user
      final user = await client.createUser(
        token: adminToken,
        username: 'update_pass_test_${DateTime.now().millisecondsSinceEpoch}',
        password: 'oldpassword',
      );
      createdUserId = user.id;

      // Update password
      final updated = await client.updateUser(
        token: adminToken,
        userId: createdUserId,
        password: 'newpassword',
      );

      expect(updated.id, equals(createdUserId));

      // Verify new password works
      expect(
        await client.login('${user.username}', 'newpassword'),
        isNotNull,
      );
    });

    test('Update user admin status', () async {
      // Create a non-admin user
      final user = await client.createUser(
        token: adminToken,
        username: 'update_admin_test_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
        isAdmin: false,
      );
      createdUserId = user.id;

      // Update to admin
      final updated = await client.updateUser(
        token: adminToken,
        userId: createdUserId,
        isAdmin: true,
      );

      expect(updated.isAdmin, isTrue);
    });

    test('Update user active status', () async {
      // Create a user
      final user = await client.createUser(
        token: adminToken,
        username: 'update_active_test_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
        isActive: true,
      );
      createdUserId = user.id;

      // Deactivate user
      final updated = await client.updateUser(
        token: adminToken,
        userId: createdUserId,
        isActive: false,
      );

      expect(updated.isActive, isFalse);
    });

    test('Update user permissions', () async {
      // Create a user with no permissions
      final user = await client.createUser(
        token: adminToken,
        username: 'update_perms_test_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
        permissions: [],
      );
      createdUserId = user.id;

      // Add permissions
      final updated = await client.updateUser(
        token: adminToken,
        userId: createdUserId,
        permissions: ['read', 'write', 'delete'],
      );

      expect(updated.permissions, containsAll(['read', 'write', 'delete']));
    });

    test('Update non-existent user throws NotFoundException', () async {
      expect(
        () => client.updateUser(
          token: adminToken,
          userId: 999999,
          isAdmin: true,
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('Delete user successfully', () async {
      // Create a user
      final user = await client.createUser(
        token: adminToken,
        username: 'delete_test_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
      );
      final userId = user.id;

      // Delete the user
      await client.deleteUser(token: adminToken, userId: userId);

      // Verify user is deleted
      expect(
        () => client.getUser(token: adminToken, userId: userId),
        throwsA(isA<NotFoundException>()),
      );

      // Reset createdUserId since we already deleted it
      createdUserId = -1;
    });

    test('Delete non-existent user throws NotFoundException', () async {
      expect(
        () => client.deleteUser(token: adminToken, userId: 999999),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('Multiple operations on same user', () async {
      // Create user
      var user = await client.createUser(
        token: adminToken,
        username: 'multi_op_test_${DateTime.now().millisecondsSinceEpoch}',
        password: 'password123',
        isAdmin: false,
        permissions: ['read'],
      );
      createdUserId = user.id;

      // Update permissions
      user = await client.updateUser(
        token: adminToken,
        userId: createdUserId,
        permissions: ['read', 'write'],
      );
      expect(user.permissions, containsAll(['read', 'write']));

      // Update admin status
      user = await client.updateUser(
        token: adminToken,
        userId: createdUserId,
        isAdmin: true,
      );
      expect(user.isAdmin, isTrue);

      // Verify final state
      final finalUser = await client.getUser(
        token: adminToken,
        userId: createdUserId,
      );
      expect(finalUser.isAdmin, isTrue);
      expect(finalUser.permissions, containsAll(['read', 'write']));
    });
  });
}
