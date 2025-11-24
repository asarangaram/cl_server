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
   pip install -r requirements.txt
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

Partially updates an entity. This endpoint is also used to **restore** a soft-deleted entity.

**Body (JSON):**
```json
{
  "body": {
    "label": "New Label",
    "is_deleted": false  // Set to false to restore a deleted entity
  }
}
```

#### Delete Entity
`DELETE /entity/{id}`

Soft deletes an entity by setting the `is_deleted` flag to `true`. The entity remains in the database and can be restored using the PATCH endpoint.

### Versioning

#### Get Entity Versions
`GET /entity/{id}/versions`

Retrieves a list of all historical versions for an entity.

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
