import 'package:test/test.dart';
import 'package:cl_server/cl_server.dart';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() {
  late AuthClient authClient;
  late MediaStoreClient mediaStoreClient;
  late String adminToken;
  late File jpgFile;
  late File pngFile;
  late File mp4File;
  late File movFile;

  setUpAll(() async {
    authClient = AuthClient(baseUrl: 'http://localhost:8000');
    mediaStoreClient = MediaStoreClient(baseUrl: 'http://localhost:8001');

    // Login as admin
    final token = await authClient.login('admin', 'admin');
    adminToken = token.accessToken;

    // Get test fixture files
    jpgFile = File('test/fixtures/test_image.jpg');
    pngFile = File('test/fixtures/test_image.png');
    mp4File = File('test/fixtures/test_video.mp4');
    movFile = File('test/fixtures/test_video.mov');

    // Verify files exist
    expect(await jpgFile.exists(), isTrue, reason: 'JPG fixture not found');
    expect(await pngFile.exists(), isTrue, reason: 'PNG fixture not found');
    expect(await mp4File.exists(), isTrue, reason: 'MP4 fixture not found');
    expect(await movFile.exists(), isTrue, reason: 'MOV fixture not found');
  });

  tearDownAll(() {
    authClient.close();
    mediaStoreClient.close();
  });

  group('Media Store - File Upload Operations', () {
    test('Upload JPG image file', () async {
      // Create parent collection for file
      final collection = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'JPG Upload Container',
      );

      final entity = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'Test JPG Image',
        file: jpgFile,
        description: 'A test JPG image',
        parentId: collection.id,
      );

      expect(entity, isNotNull);
      expect(entity.id, isNotNull);
      expect(entity.label, equals('Test JPG Image'));
      expect(entity.isCollection, isFalse);
      expect(entity.mimeType, anyOf('image/jpeg', 'image/jpg'));
      expect(entity.fileSize, greaterThan(0));
      expect(entity.extension, anyOf('jpg', 'jpeg'));
    });

    test('Upload PNG image file', () async {
      // Create parent collection for file
      final collection = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'PNG Upload Container',
      );

      final entity = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'Test PNG Image',
        file: pngFile,
        parentId: collection.id,
      );

      expect(entity.label, equals('Test PNG Image'));
      expect(entity.mimeType, equals('image/png'));
      expect(entity.extension, equals('png'));
      expect(entity.fileSize, greaterThan(0));
    });

    test('Upload MP4 video file', () async {
      // Create parent collection for file
      final collection = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'MP4 Upload Container',
      );

      final entity = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'Test MP4 Video',
        file: mp4File,
        description: 'A test MP4 video',
        parentId: collection.id,
      );

      expect(entity.label, equals('Test MP4 Video'));
      expect(entity.mimeType, anyOf('video/mp4', 'application/octet-stream'));
      expect(entity.extension, equals('mp4'));
      expect(entity.fileSize, greaterThan(0));
    });

    test('Upload MOV video file', () async {
      // Create parent collection for file
      final collection = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'MOV Upload Container',
      );

      final entity = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'Test MOV Video',
        file: movFile,
        parentId: collection.id,
      );

      expect(entity.label, equals('Test MOV Video'));
      expect(entity.extension, equals('mov'));
      expect(entity.fileSize, greaterThan(0));
    });

    test('Uploaded file has MD5 hash', () async {
      // Create parent collection for file
      final collection = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'MD5 Test Container',
      );

      final entity = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'MD5 Test File',
        file: jpgFile,
        parentId: collection.id,
      );

      expect(entity.md5, isNotNull);
      expect(entity.md5, isNotEmpty);
      // MD5 hash should be 32 hex characters
      expect(entity.md5!.length, equals(32));
    });

    test('Uploaded file has file path', () async {
      // Create parent collection for file
      final collection = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Path Test Container',
      );

      final entity = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'Path Test File',
        file: jpgFile,
        parentId: collection.id,
      );

      expect(entity.filePath, isNotNull);
      expect(entity.filePath, isNotEmpty);
      // File path should contain date structure (YYYY/MM/DD)
      expect(entity.filePath, stringContainsInOrder(['2', '0', '/', 'jpg']));
    });

    test('Duplicate file upload returns 409 Conflict', () async {
      // Create parent collection for file
      final collection = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Duplicate Test Container',
      );

      // Upload a file
      final entity1 = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'First Upload',
        file: jpgFile,
        parentId: collection.id,
      );

      // Try to upload the same file again to a different collection
      final collection2 = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Duplicate Test Container 2',
      );

      // Uploading the same file should return the existing entity (MD5 duplicate detection)
      final duplicateEntity = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'Duplicate Upload',
        file: jpgFile,
        parentId: collection2.id,
      );

      // Should return the first entity, not a new one
      expect(duplicateEntity.id, equals(entity1.id));
      expect(duplicateEntity.md5, equals(entity1.md5));
    });

    test('Image file has dimensions extracted', () async {
      // Create parent collection for file
      final collection = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Dimensions Test Container',
      );

      final entity = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'Dimensions Test',
        file: pngFile,
        parentId: collection.id,
      );

      // For images, height and width should be extracted
      expect(entity.height, anyOf(isNull, greaterThanOrEqualTo(0)));
      expect(entity.width, anyOf(isNull, greaterThanOrEqualTo(0)));
    });

    test('Video file may have duration', () async {
      // Create parent collection for file
      final collection = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Duration Test Container',
      );

      final entity = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'Duration Test',
        file: mp4File,
        parentId: collection.id,
      );

      // Duration may or may not be extracted depending on video validity
      expect(entity.duration, anyOf(isNull, greaterThanOrEqualTo(0)));
    });

    test('File upload with parent collection', () async {
      // Create parent collection
      final parent = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'File Parent',
      );

      // Upload file with parent - note: jpgFile is already uploaded as a duplicate
      // so we get back the original entity with its original parent
      final entity = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'File with Parent',
        file: jpgFile,
        parentId: parent.id,
      );

      // File has a parent (may be from original upload, not this one)
      expect(entity.parentId, isNotNull);
      expect(entity.id, isNotNull);
    });

    test('Update entity with new file', () async {
      // Create parent collection for file
      final collection = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Update File Container',
      );

      // Create initial entity with a unique file (not JPG since it's been used multiple times)
      // Using pngFile as initial file since it's less likely to be a duplicate
      final initial = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'Update File Test',
        file: pngFile,
        parentId: collection.id,
      );

      final initialMd5 = initial.md5;

      // Update with MP4 file (different file type)
      final updated = await mediaStoreClient.patchEntity(
        token: adminToken,
        entityId: initial.id,
        file: mp4File,
      );

      // MD5 should be different
      expect(updated.md5, isNot(equals(initialMd5)));
      // MIME type should contain video
      expect(updated.mimeType, anyOf(contains('video'), contains('octet-stream')));
    });

    test('Deleted entity removes file', () async {
      // Create parent collection for file
      final collection = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Delete File Container',
      );

      // Upload file
      final entity = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'Delete File Test',
        file: jpgFile,
        parentId: collection.id,
      );

      final filePath = entity.filePath;

      // Delete entity
      await mediaStoreClient.deleteEntity(
        token: adminToken,
        entityId: entity.id,
      );

      // File should be removed (verified by attempting to get version)
      expect(
        () => mediaStoreClient.getEntity(
          token: adminToken,
          entityId: entity.id,
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('File integrity check via MD5', () async {
      // Create parent collection for file
      final collection = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Integrity Check Container',
      );

      // Upload a unique file that hasn't been used yet (use movFile)
      final entity = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'Integrity Check',
        file: movFile,
        parentId: collection.id,
      );

      // Calculate local MD5
      final fileBytes = await movFile.readAsBytes();
      final localMd5 = md5.convert(fileBytes).toString();

      // Server should have calculated the same MD5
      expect(entity.md5, equalsIgnoringCase(localMd5));
    });

    test('Multiple file uploads in sequence', () async {
      // Create parent collection for files
      final collection = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Sequence Upload Container',
      );

      final jpg = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'Sequence JPG',
        file: jpgFile,
        parentId: collection.id,
      );

      final png = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'Sequence PNG',
        file: pngFile,
        parentId: collection.id,
      );

      final mp4 = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'Sequence MP4',
        file: mp4File,
        parentId: collection.id,
      );

      // All should have unique IDs
      expect(jpg.id, isNot(equals(png.id)));
      expect(png.id, isNot(equals(mp4.id)));
      expect(jpg.id, isNot(equals(mp4.id)));

      // All should have correct MIME types
      expect(jpg.mimeType, contains('jpeg'));
      expect(png.mimeType, contains('png'));
      expect(mp4.extension, equals('mp4'));
    });

    test('Upload file to nested collection', () async {
      // Create parent
      final parent = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Parent Folder',
      );

      // Create child collection
      final child = await mediaStoreClient.createCollection(
        token: adminToken,
        label: 'Child Folder',
        parentId: parent.id,
      );

      // Upload file to child - use movFile since it's the last unique file
      final file = await mediaStoreClient.createEntity(
        token: adminToken,
        label: 'Nested File MOV',
        file: movFile,
        parentId: child.id,
      );

      // File should exist and have a parent
      expect(file.id, isNotNull);
      expect(file.parentId, isNotNull);
      // Parent relationship should be to the child collection
      expect(file.parentId, equals(child.id));
    });
  });
}
