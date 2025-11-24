# CoLAN Server Tests

Pytest-based test suite for the CoLAN server API.

## Running Tests

### Run all tests:
```bash
pytest
```

### Run with verbose output:
```bash
pytest -v
```

### Run specific test file:
```bash
pytest tests/test_file_upload.py
```

### Run specific test:
```bash
pytest tests/test_file_upload.py::TestFileUpload::test_upload_image_with_metadata
```

### Run with coverage:
```bash
pytest --cov=server --cov-report=html
```

## Test Structure

- `conftest.py` - Pytest configuration and fixtures
- `test_file_upload.py` - File upload and metadata extraction tests
- `test_duplicate_detection.py` - MD5-based duplicate detection tests
- `test_file_storage.py` - File storage organization tests
- `test_entity_crud.py` - CRUD operation tests

## Fixtures

- `client` - FastAPI TestClient with fresh database
- `test_db` - In-memory SQLite database for testing
- `clean_media_dir` - Temporary media directory (auto-cleaned)
- `sample_image` - Single test image from ./images
- `sample_images` - Multiple test images from ./images

## Requirements

- Test images must be present in `./images` directory
- ExifTool must be installed (`brew install exiftool`)
- All dependencies from `requirements.txt`
