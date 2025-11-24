# CoLAN Server Tests

Comprehensive pytest-based test suite for the CoLAN server API.

## Quick Start

```bash
# Run all tests
pytest

# Run with verbose output
pytest -v

# Run with coverage report
pytest --cov=server --cov-report=html
```

## Test Structure

- `conftest.py`: Pytest configuration and fixtures
- `test_entity_crud.py`: CRUD operations (Create, Read, Update, Delete)
- `test_pagination.py`: Pagination and versioning integration
- `test_versioning.py`: Entity versioning logic
- `test_entity_validation.py`: Validation rules
- `test_duplicate_detection.py`: MD5-based duplicate detection
- `test_file_upload.py`: File upload and metadata extraction
- `test_file_storage.py`: File storage organization
- `test_comprehensive_metadata.py`: Deep metadata verification

---

## Adding Test Media

Simply add your media files to the `images/` directory (in the project root) and the tests will automatically pick them up!

```bash
# Add a single file
cp /path/to/your/image.jpg images/

# Add multiple files
cp /path/to/your/photos/*.jpg images/
```

### Supported File Types
The parametrized tests automatically discover:
- **Images**: `.jpg`, `.jpeg`, `.png`, `.gif` (case-insensitive)
- **Videos**: Supported in code but requires adding video files to `images/`

---

## Test Coverage Summary

**Total Tests**: 89+ (continuously growing)

### Key Areas Covered

1. **Pagination & Versioning** ✅
   - Basic pagination (page/size)
   - Versioning integration (historical data)
   - Edge cases (invalid params)

2. **Entity CRUD** ✅
   - Create, Read, Update, Delete, Patch
   - Error handling (404, 400, 409)

3. **Validation Rules** ✅
   - Image requirement logic
   - Collection constraints
   - Immutable fields

4. **Duplicate Detection** ✅
   - Rejects duplicate MD5 uploads
   - Allows same-entity updates

5. **Metadata Extraction** ✅
   - Dimensions, Size, MIME type, MD5
   - EXIF data (where available)

### Field Coverage

| Field | Status | Notes |
|-------|--------|-------|
| `id` | ✅ Tested | Primary key |
| `is_collection` | ✅ Tested | Immutable flag |
| `label` | ✅ Tested | |
| `description` | ✅ Tested | |
| `parent_id` | ✅ Tested | |
| `file_size` | ✅ Tested | Verified against actual |
| `width/height` | ✅ Tested | Verified > 0 |
| `mime_type` | ✅ Tested | |
| `md5` | ✅ Tested | Duplicate detection |
| `is_deleted` | ✅ Tested | Soft delete |
| `added_date` | ⚠️ Partial | Existence checked |
| `updated_date` | ⚠️ Partial | Existence checked |
| `create_date` | ⚠️ Missing | Needs EXIF test images |
| `duration` | ⚠️ Missing | Needs video test files |

---

## Pytest Migration Notes

The test suite was migrated from bash scripts to pytest to provide:
- **Speed**: In-memory SQLite database
- **Isolation**: Fresh database per test
- **Debugging**: Better failure reporting
- **Coverage**: Integrated code coverage

### Fixtures
- `client`: FastAPI TestClient
- `test_db`: In-memory SQLite session
- `clean_media_dir`: Auto-cleaned temp directory
- `sample_images`: Auto-discovered test images
