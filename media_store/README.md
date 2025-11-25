# CoLAN Media Store Service

A FastAPI-based microservice for managing media entities (images, videos) with metadata extraction, versioning, and duplicate detection.

## Setup

### Prerequisites
- Python 3.9+
- `exiftool` (for metadata extraction)

### Installation

1. **Install System Dependencies**
   ```bash
   # macOS
   brew install exiftool
   
   # Linux (Ubuntu/Debian)
   sudo apt-get install libimage-exiftool-perl
   ```

2. **Install Python Dependencies**
   ```bash
   # Recommended: Install directly from pyproject.toml
   pip install -e .
   ```
   
   **Optional: Generate `requirements.txt` from `pyproject.toml`**
   
   If you need a `requirements.txt` file for deployment or compatibility:
   ```bash
   # Install the package first
   pip install -e .
   
   # Generate requirements.txt with pinned versions
   pip freeze > requirements.txt
   
   # Or use pip-tools for better control
   pip install pip-tools
   pip-compile pyproject.toml
   ```

3. **Configure Data Directories** (Optional)
   
   By default, the application stores data in `../data/` (outside the `media_store/` directory):
   - Database: `../data/media_store.db`
   - Media files: `../data/media_store/`
   
   You can override these paths using environment variables:
   ```bash
   export DATABASE_DIR="/path/to/your/data"
   export MEDIA_STORAGE_DIR="/path/to/your/media"
   # Or override the full database URL
   export DATABASE_URL="sqlite:////path/to/your/database.db"
   ```

## Running the Server

```bash
# Run with hot reload (development)
uvicorn main:app --reload

# Run in production
uvicorn main:app --host 0.0.0.0 --port 8000
```

The API will be available at `http://localhost:8000`.
Interactive documentation: `http://localhost:8000/docs`.

## API Endpoints

### Entities

#### List Entities
`GET /entity/`

Retrieves a paginated list of entities.

**Parameters:**
- `page`: Page number (default: 1)
- `page_size`: Items per page (default: 20, max: 100)
- `version`: Optional version number to retrieve historical data
- `filter_param`: Optional filter string
- `search_query`: Optional search query

**Response:**
```json
{
  "items": [ ... ],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total_items": 100,
    "total_pages": 5,
    "has_next": true,
    "has_prev": false
  }
}
```

#### Create Entity
`POST /entity/`

Creates a new entity.

**Body (Multipart/Form-Data):**
- `image`: File (Required if `is_collection=false`)
- `is_collection`: Boolean (default: false)
- `label`: String
- `description`: String (optional)
- `parent_id`: Integer (optional)

#### Get Entity
`GET /entity/{id}`

Retrieves a specific entity by ID.

#### Update Entity
`PUT /entity/{id}`

Updates an entity. Can replace the file or update metadata.

**Body (Multipart/Form-Data):**
- `image`: File (Optional for non-collections)
- `is_collection`: Boolean (Immutable)
- `label`: String
- `description`: String
- `parent_id`: Integer

#### Patch Entity
`PATCH /entity/{id}`

Partially updates an entity. This endpoint is versatile and can be used to:
- **Update Metadata**: Change `label` or `description`.
- **Modify Hierarchy**: Change `parent_id` to move an entity to a different collection (or set to `null` to remove from collection).
- **Soft Delete/Restore**: Set `is_deleted` to `true` (soft delete) or `false` (restore).

**Body (JSON):**
```json
{
  "body": {
    "label": "New Label",
    "parent_id": 123,   // Move to collection 123
    "is_deleted": false // Restore if deleted
  }
}
```

#### Delete Entity
`DELETE /entity/{id}`

**WARNING: This is a non-recoverable action.**
Permanently deletes the entity record from the database and removes the associated file from the storage. For reversible deletion, use the PATCH endpoint with `is_deleted=true`.

### Versioning

#### Get Entity Versions
`GET /entity/{id}/versions`

Retrieves a list of all historical versions for an entity.

### Response Structure
All entity endpoints return an **Item** object:

```json
{
  "id": 1,
  "is_collection": false,
  "label": "My Image",
  "description": "A test image",
  "parent_id": null,
  "added_date": "2023-10-27T10:00:00Z",
  "updated_date": "2023-10-27T10:00:00Z",
  "create_date": "2023-01-01T12:00:00Z", // From EXIF if available
  "file_size": 102400,
  "height": 1080,
  "width": 1920,
  "duration": null,
  "mime_type": "image/jpeg",
  "type": "image",
  "extension": "jpg",
  "md5": "d41d8cd98f00b204e9800998ecf8427e",
  "file_path": "2023/10/27/d41d8cd98f00b204e9800998ecf8427e.jpg",
  "is_deleted": false
}
```

## Key Features

### File Storage & Naming
Files are stored securely to prevent accidental overwrites.
- **Naming Convention**: Files are renamed to `{md5}.{extension}` (e.g., `d41d8cd98f00b204e9800998ecf8427e.jpg`).
- **Collision Prevention**: This ensures that uploading a file with the same name but different content will not overwrite the existing file.
- **Duplicate Detection**: Uploading a file with the exact same content (same MD5) as an existing entity is rejected with a `409 Conflict` error.

### Other Features
- **Metadata Extraction**: Automatically extracts width, height, file size, MIME type, and MD5 hash.
- **Versioning**: Tracks history of all changes. Query past states using the `version` parameter.
- **Soft Deletes**: Entities are marked as deleted rather than removed from the database.
- **Pagination**: Efficiently handles large datasets.
