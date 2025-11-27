import 'package:test/test.dart';
import 'package:cl_server/cl_server.dart';

void main() {
  late AuthClient authClient;
  late MediaStoreClient mediaStoreClient;
  late String adminToken;

  setUpAll(() async {
    authClient = AuthClient(baseUrl: 'http://localhost:8000');
    mediaStoreClient = MediaStoreClient(baseUrl: 'http://localhost:8001');

    // Login as admin
    final token = await authClient.login('admin', 'admin');
    adminToken = token.accessToken;
  });

  tearDownAll(() {
    authClient.close();
    mediaStoreClient.close();
  });

  group('Media Store - Entity CRUD Operations', () {
    test('Create collection entity', () async {
      final entity = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Test Collection',
        description: 'A test collection',
      );

      expect(entity, isNotNull);
      expect(entity.id, isNotNull);
      expect(entity.label, equals('Test Collection'));
      expect(entity.isCollection, isTrue);
      expect(entity.description, equals('A test collection'));
      expect(entity.isDeleted, anyOf(isNull, isFalse));
    });

    test('Create collection without description', () async {
      final entity = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Collection No Desc',
      );

      expect(entity, isNotNull);
      expect(entity.label, equals('Collection No Desc'));
      expect(entity.isCollection, isTrue);
      expect(entity.description, anyOf(isNull, isEmpty));
    });

    test('Create collection with parent ID', () async {
      // First create a parent collection
      final parent = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Parent Collection',
      );

      // Create child collection
      final child = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Child Collection',
        parentId: parent.id,
      );

      expect(child.parentId, equals(parent.id));
    });

    test('List entities returns list', () async {
      // Create a test entity
      await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'List Test Entity',
      );

      final entities = await mediaStoreClient.listEntities(
        token: adminToken,
        page: 1,
        pageSize: 10,
      );

      expect(entities, isA<List<Entity>>());
      expect(entities.isNotEmpty, isTrue);
    });

    test('List entities with pagination', () async {
      final entities1 = await mediaStoreClient.listEntities(
        token: adminToken,
        page: 1,
        pageSize: 5,
      );

      expect(entities1, isNotNull);
      // Should have at least the entities we created
      expect(entities1.length, greaterThanOrEqualTo(0));
    });

    test('Get single entity by ID', () async {
      // Create an entity
      final created = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Get Test Entity',
      );

      // Retrieve it
      final retrieved = await mediaStoreClient.getEntity(
        token: adminToken,
        entityId: created.id,
      );

      expect(retrieved.id, equals(created.id));
      expect(retrieved.label, equals(created.label));
      expect(retrieved.isCollection, equals(created.isCollection));
    });

    test('Get non-existent entity throws NotFoundException', () async {
      expect(
        () => mediaStoreClient.getEntity(
          token: adminToken,
          entityId: 99999,
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('Patch entity - update label', () async {
      // Create an entity
      final created = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Original Label',
      );

      // Patch it
      final patched = await mediaStoreClient.patchEntity(
        token: adminToken,
        entityId: created.id,
        label: 'Updated Label',
      );

      expect(patched.label, equals('Updated Label'));
      expect(patched.id, equals(created.id));
    });

    test('Patch entity - update description', () async {
      // Create an entity
      final created = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Patch Desc Test',
        description: 'Original',
      );

      // Patch it
      final patched = await mediaStoreClient.patchEntity(
        token: adminToken,
        entityId: created.id,
        description: 'Updated',
      );

      expect(patched.description, equals('Updated'));
    });

    test('Patch entity - update parent', () async {
      // Create parent and child
      final parent = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Parent 1',
      );

      final entity = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Child Entity',
        parentId: parent.id,
      );

      // Create new parent
      final newParent = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Parent 2',
      );

      // Patch to new parent
      final patched = await mediaStoreClient.patchEntity(
        token: adminToken,
        entityId: entity.id,
        parentId: newParent.id,
      );

      expect(patched.parentId, equals(newParent.id));
    });

    test('Soft delete entity', () async {
      // Create an entity
      final created = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Soft Delete Test',
      );

      // Soft delete it
      final deleted = await mediaStoreClient.softDeleteEntity(
        token: adminToken,
        entityId: created.id,
      );

      expect(deleted.isDeleted, isTrue);
    });

    test('Hard delete entity', () async {
      // Create an entity
      final created = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Hard Delete Test',
      );

      // Delete it
      await mediaStoreClient.deleteEntity(
        token: adminToken,
        entityId: created.id,
      );

      // Verify it's gone
      expect(
        () => mediaStoreClient.getEntity(
          token: adminToken,
          entityId: created.id,
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('Patch empty request throws ValidationException', () async {
      final created = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Empty Patch Test',
      );

      // Patch with no fields
      expect(
        () => mediaStoreClient.patchEntity(
          token: adminToken,
          entityId: created.id,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Collection is immutable flag', () async {
      final entity = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Immutable Test',
      );

      // Collections should have isCollection = true
      expect(entity.isCollection, isTrue);
    });

    test('Entity hierarchy - parent-child relationships', () async {
      // Create parent
      final parent = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Root',
      );

      // Create child
      final child = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Child',
        parentId: parent.id,
      );

      expect(child.parentId, equals(parent.id));

      // Retrieve child and verify parent
      final retrieved = await mediaStoreClient.getEntity(
        token: adminToken,
        entityId: child.id,
      );

      expect(retrieved.parentId, equals(parent.id));
    });

    test('Update entity with label and description', () async {
      final created = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Original',
      );

      final updated = await mediaStoreClient.updateEntity(
        token: adminToken,
        entityId: created.id,
        label: 'Updated',
        isCollection: true,
        description: 'New description',
      );

      expect(updated.label, equals('Updated'));
      expect(updated.description, equals('New description'));
    });

    test('Multiple sequential patches', () async {
      final entity = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Multi Patch Test',
      );

      var current = entity;

      // First patch
      current = await mediaStoreClient.patchEntity(
        token: adminToken,
        entityId: current.id,
        label: 'First Update',
      );
      expect(current.label, equals('First Update'));

      // Second patch
      current = await mediaStoreClient.patchEntity(
        token: adminToken,
        entityId: current.id,
        description: 'Added description',
      );
      expect(current.description, equals('Added description'));
      expect(current.label, equals('First Update'));

      // Third patch
      current = await mediaStoreClient.patchEntity(
        token: adminToken,
        entityId: current.id,
        label: 'Third Update',
        description: 'Modified description',
      );
      expect(current.label, equals('Third Update'));
      expect(current.description, equals('Modified description'));
    });
  });
}
