import 'package:test/test.dart';
import 'package:cl_server/cl_server.dart';
import 'dart:io';

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

  group('CLI - Media Commands Integration', () {
    test('CLI: List media entities', () async {
      // Create a test entity first
      await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'CLI List Test',
      );

      // Simulate CLI command: media list
      final entities = await mediaStoreClient.listEntities(
        token: adminToken,
        page: 1,
        pageSize: 10,
      );

      expect(entities, isA<List<Entity>>());
      expect(entities.isNotEmpty, isTrue);
      // Verify we can find our test entity
      expect(
        entities.any((e) => e.label.contains('CLI List Test')),
        isTrue,
      );
    });

    test('CLI: Get media entity details', () async {
      // Create a test entity
      final created = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'CLI Get Test',
        description: 'Test entity for CLI get command',
      );

      // Simulate CLI command: media get <id>
      final entity = await mediaStoreClient.getEntity(
        token: adminToken,
        entityId: created.id,
      );

      expect(entity.id, equals(created.id));
      expect(entity.label, equals('CLI Get Test'));
      expect(entity.description, equals('Test entity for CLI get command'));
    });

    test('CLI: Create collection via media command', () async {
      // Simulate CLI command: media create-collection "My Files"
      final collection = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'CLI Created Collection',
      );

      expect(collection.id, isNotNull);
      expect(collection.label, equals('CLI Created Collection'));
      expect(collection.isCollection, isTrue);
    });

    test('CLI: Create collection with description', () async {
      // Simulate CLI command: media create-collection "Docs" --desc "My Documents"
      final collection = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Docs',
        description: 'My Documents',
      );

      expect(collection.label, equals('Docs'));
      expect(collection.description, equals('My Documents'));
    });

    test('CLI: Upload file via media command', () async {
      final testFile = File('test/fixtures/test_image.jpg');
      if (!await testFile.exists()) {
        return; // Skip if file not found
      }

      // Create parent collection for file
      final container = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'CLI Upload Container',
      );

      // Simulate CLI command: media upload /path/to/file.jpg --name "My Photo"
      final uploaded = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'My Photo',
        file: testFile,
        parentId: container.id,
      );

      expect(uploaded.id, isNotNull);
      expect(uploaded.label, equals('My Photo'));
      expect(uploaded.isCollection, isFalse);
      expect(uploaded.fileSize, greaterThan(0));
    });

    test('CLI: Upload file with parent collection', () async {
      final testFile = File('test/fixtures/test_image.png');
      if (!await testFile.exists()) {
        return; // Skip if file not found
      }

      // Create parent collection
      final parent = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'CLI Upload Parent',
      );

      // Simulate CLI command: media upload /path/to/file.png --parent <parent_id>
      final uploaded = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'Uploaded to Parent',
        file: testFile,
        parentId: parent.id,
      );

      expect(uploaded.parentId, equals(parent.id));
    });

    test('CLI: Patch entity label', () async {
      // Create entity
      final created = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Original Label',
      );

      // Simulate CLI command: media patch <id> --label "New Label"
      final patched = await mediaStoreClient.patchEntity(
        token: adminToken,
        entityId: created.id,
        label: 'New Label',
      );

      expect(patched.label, equals('New Label'));
    });

    test('CLI: Patch entity description', () async {
      // Create entity
      final created = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Patch Desc Test',
      );

      // Simulate CLI command: media patch <id> --desc "New description"
      final patched = await mediaStoreClient.patchEntity(
        token: adminToken,
        entityId: created.id,
        description: 'New description',
      );

      expect(patched.description, equals('New description'));
    });

    test('CLI: Patch entity with multiple fields', () async {
      final created = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Original',
      );

      // Simulate CLI command: media patch <id> --label "Updated" --desc "New"
      final patched = await mediaStoreClient.patchEntity(
        token: adminToken,
        entityId: created.id,
        label: 'Updated',
        description: 'New',
      );

      expect(patched.label, equals('Updated'));
      expect(patched.description, equals('New'));
    });

    test('CLI: Delete entity', () async {
      // Create entity
      final created = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'CLI Delete Test',
      );

      // Simulate CLI command: media delete <id>
      await mediaStoreClient.deleteEntity(
        token: adminToken,
        entityId: created.id,
      );

      // Verify it's deleted
      expect(
        () => mediaStoreClient.getEntity(
          token: adminToken,
          entityId: created.id,
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('CLI: List versions of entity', () async {
      // Create entity
      final created = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Version Test',
      );

      // Make updates
      await mediaStoreClient.patchEntity(
        token: adminToken,
        entityId: created.id,
        label: 'Updated Version',
      );

      // Simulate CLI command: media versions <id>
      final versions = await mediaStoreClient.getVersions(
        token: adminToken,
        entityId: created.id,
      );

      expect(versions, isA<List<Entity>>());
      expect(versions.length, greaterThanOrEqualTo(2));
    });

    test('CLI: Get service config', () async {
      // Simulate CLI command: media config-get
      final config = await mediaStoreClient.getConfig(token: adminToken);

      expect(config, isNotNull);
      expect(config.readAuthEnabled, isA<bool>());
    });

    test('CLI: Set read auth configuration', () async {
      // Simulate CLI command: media config-set true
      final config = await mediaStoreClient.setReadAuth(
        token: adminToken,
        readAuthEnabled: true,
      );

      expect(config.readAuthEnabled, isTrue);

      // Simulate CLI command: media config-set false
      final configDisabled = await mediaStoreClient.setReadAuth(
        token: adminToken,
        readAuthEnabled: false,
      );

      expect(configDisabled.readAuthEnabled, isFalse);
    });

    test('CLI: Handle invalid entity ID', () async {
      // Simulate CLI command: media get <invalid_id>
      expect(
        () => mediaStoreClient.getEntity(
          token: adminToken,
          entityId: 99999,
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('CLI: Handle duplicate file upload error', () async {
      final testFile = File('test/fixtures/test_image.jpg');
      if (!await testFile.exists()) {
        return; // Skip if file not found
      }

      // Create parent collection for files
      final container = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'CLI Duplicate Test Container',
      );

      // First upload
      await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'First Upload',
        file: testFile,
        parentId: container.id,
      );

      // Create second collection for duplicate upload test
      final container2 = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'CLI Duplicate Test Container 2',
      );

      // Second upload of same file should fail
      expect(
        () => mediaStoreClient.createEntity(
          token: adminToken,
          label: 'Duplicate Upload',
          file: testFile,
          parentId: container2.id,
        ),
        throwsA(isA<DuplicateResourceException>()),
      );
    });

    test('CLI: Upload different file formats', () async {
      final jpgFile = File('test/fixtures/test_image.jpg');
      final pngFile = File('test/fixtures/test_image.png');
      final mp4File = File('test/fixtures/test_video.mp4');

      if (!await jpgFile.exists() ||
          !await pngFile.exists() ||
          !await mp4File.exists()) {
        return; // Skip if files not found
      }

      // Create parent collection for files
      final container = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'CLI Format Test Container',
      );

      // Simulate uploading different file types
      final jpg = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'CLI JPG',
        file: jpgFile,
        parentId: container.id,
      );

      final png = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'CLI PNG',
        file: pngFile,
        parentId: container.id,
      );

      final mp4 = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'CLI MP4',
        file: mp4File,
        parentId: container.id,
      );

      expect(jpg.extension, anyOf('jpg', 'jpeg'));
      expect(png.extension, equals('png'));
      expect(mp4.extension, equals('mp4'));
    });

    test('CLI: Create nested collection structure', () async {
      // Simulate CLI commands:
      // media create-collection "Projects"
      // media create-collection "2025" --parent <projects_id>
      // media create-collection "January" --parent <2025_id>

      final projects = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Projects',
      );

      final year2025 = await mediaStoreClient.createCollection(
        token: adminToken,
        label: '2025',
        parentId: projects.id,
      );

      final january = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'January',
        parentId: year2025.id,
      );

      expect(year2025.parentId, equals(projects.id));
      expect(january.parentId, equals(year2025.id));
    });

    test('CLI: Full workflow - create, upload, update, version', () async {
      final testFile = File('test/fixtures/test_image.png');
      if (!await testFile.exists()) {
        return; // Skip if file not found
      }

      // Create collection
      final folder = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'CLI Workflow Test',
        description: 'Test collection',
      );

      // Upload file to collection
      var entity = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'CLI Workflow File',
        file: testFile,
        parentId: folder.id,
      );

      expect(entity.parentId, equals(folder.id));
      expect(entity.label, equals('CLI Workflow File'));

      // Update entity
      entity = await mediaStoreClient.patchEntity(
        token: adminToken,
        entityId: entity.id,
        description: 'Updated workflow file',
      );

      expect(entity.description, equals('Updated workflow file'));

      // Get versions
      final versions = await mediaStoreClient.getVersions(
        token: adminToken,
        entityId: entity.id,
      );

      expect(versions.length, greaterThanOrEqualTo(2)); // Creation + patch
    });
  });
}
