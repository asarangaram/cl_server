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
  ## Adding Test Media

To add new test images or videos:
1.  Add the **absolute path** of the file to `tests/test_files.txt`.
2.  Ensure the file exists at that location.
3.  The test suite will automatically load these files.

## Test Coverage

### Field Coverage
| Field | Status | Notes |
| :--- | :--- | :--- |
| `id` | ✅ Covered | Auto-incrementing primary key |
| `is_collection` | ✅ Covered | Tested for both True/False |
| `label` | ✅ Covered | Basic string field |
| `description` | ✅ Covered | Basic string field |
| `parent_id` | ✅ Covered | Tested for hierarchy |
| `added_date` | ✅ Covered | System managed |
| `updated_date` | ✅ Covered | System managed |
| `create_date` | ✅ Covered | Extracted from EXIF |
| `file_size` | ✅ Covered | Extracted from file |
| `height` | ✅ Covered | Extracted from image |
| `width` | ✅ Covered | Extracted from image |
| `duration` | ⚠️ Partial | Logic exists, needs video test files |
| `mime_type` | ✅ Covered | Extracted from file |
| `type` | ✅ Covered | Extracted from file |
| `extension` | ✅ Covered | Extracted from file |
| `md5` | ✅ Covered | Extracted and used for duplicate detection |
| `file_path` | ✅ Covered | Verified in storage tests |
| `is_deleted` | ✅ Covered | Tested via Soft Delete/Restore |

### Feature Coverage
- **CRUD Operations**: Full coverage for Create, Read, Update, Delete (Hard & Soft).
- **Pagination**: Full coverage including edge cases.
- **Versioning**: Full coverage using SQLAlchemy-Continuum.
- **File Storage**: Verified naming convention (`{md5}.{ext}`) and directory structure.
- **Validation**: Verified constraints on `is_collection` and image requirements.

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
