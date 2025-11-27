import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Test image information
class TestImage {
  final String name;
  final String absolutePath;
  final String description;

  TestImage({
    required this.name,
    required this.absolutePath,
    required this.description,
  });

  /// Check if image file exists
  Future<bool> exists() async {
    return File(absolutePath).exists();
  }

  /// Get file size in bytes
  Future<int> getSize() async {
    final file = File(absolutePath);
    try {
      return await file.length();
    } catch (e) {
      return 0;
    }
  }

  @override
  String toString() => 'TestImage($name: $absolutePath)';
}

/// Manages loading and validation of test images from manifest
class TestImageLoader {
  static const String _manifestPath =
      'test/fixtures/image_manifest.json';

  static TestImage? _primaryImage;
  static TestImage? _secondaryImage;
  static List<TestImage>? _allImages;
  static bool _initialized = false;

  /// Initialize the image loader
  /// Must be called before using any image accessors
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final images = await _loadImagesFromManifest();
      _allImages = images;

      if (images.isNotEmpty) {
        _primaryImage = images[0];
      }
      if (images.length > 1) {
        _secondaryImage = images[1];
      }

      await _validateImages();
      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize TestImageLoader: $e');
    }
  }

  /// Load all test images
  static Future<List<TestImage>> loadAll() async {
    if (!_initialized) {
      await initialize();
    }
    return _allImages ?? [];
  }

  /// Get primary test image
  static Future<TestImage?> getPrimaryImage() async {
    if (!_initialized) {
      await initialize();
    }
    return _primaryImage;
  }

  /// Get secondary test image
  static Future<TestImage?> getSecondaryImage() async {
    if (!_initialized) {
      await initialize();
    }
    return _secondaryImage;
  }

  /// Get image by name
  static Future<TestImage?> getImageByName(String name) async {
    final images = await loadAll();
    try {
      return images.firstWhere((img) => img.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Get random image from the list
  static Future<TestImage?> getRandomImage() async {
    final images = await loadAll();
    if (images.isEmpty) return null;
    return images[DateTime.now().millisecond % images.length];
  }

  /// Get N random unique images
  static Future<List<TestImage>> getRandomImages(int count) async {
    final images = await loadAll();
    if (images.isEmpty) return [];

    final selected = <TestImage>[];
    final indices = <int>{};

    for (int i = 0; i < count && i < images.length; i++) {
      int index;
      do {
        index = DateTime.now().microsecond % images.length;
      } while (indices.contains(index));
      indices.add(index);
      selected.add(images[index]);
    }

    return selected;
  }

  /// Load images from manifest JSON
  static Future<List<TestImage>> _loadImagesFromManifest() async {
    try {
      final manifestFile = File(_manifestPath);
      if (!await manifestFile.exists()) {
        throw FileSystemException('Manifest file not found: $_manifestPath');
      }

      final jsonContent = await manifestFile.readAsString();
      final jsonData = jsonDecode(jsonContent) as Map<String, dynamic>;
      final imageList = jsonData['test_images'] as List<dynamic>;

      return imageList
          .map((item) {
            final map = item as Map<String, dynamic>;
            return TestImage(
              name: map['name'] as String? ?? 'unknown',
              absolutePath: map['absolute_path'] as String? ?? '',
              description: map['description'] as String? ?? '',
            );
          })
          .toList();
    } catch (e) {
      throw Exception('Failed to load images from manifest: $e');
    }
  }

  /// Validate that all test images exist
  static Future<void> _validateImages() async {
    if (_allImages == null || _allImages!.isEmpty) {
      throw Exception('No images loaded from manifest');
    }

    final missingImages = <String>[];

    for (final image in _allImages!) {
      if (!await image.exists()) {
        missingImages.add('${image.name}: ${image.absolutePath}');
      }
    }

    if (missingImages.isNotEmpty) {
      throw Exception(
        'Missing test images:\n${missingImages.join('\n')}',
      );
    }
  }

  /// Get information about loaded images
  static Future<Map<String, dynamic>> getLoadedImagesInfo() async {
    if (!_initialized) {
      await initialize();
    }

    final images = _allImages ?? [];
    final imageInfo = <Map<String, dynamic>>[];

    for (final image in images) {
      final size = await image.getSize();
      imageInfo.add({
        'name': image.name,
        'path': image.absolutePath,
        'size_bytes': size,
        'exists': await image.exists(),
      });
    }

    return {
      'total_images': images.length,
      'images': imageInfo,
    };
  }

  /// Reset the loader (for testing purposes)
  static void reset() {
    _primaryImage = null;
    _secondaryImage = null;
    _allImages = null;
    _initialized = false;
  }
}
