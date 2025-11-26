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

## Authentication

The media store service supports configurable authentication with three operational modes.

### Configuration Modes

#### 1. Normal Mode (Default)
Write APIs require authentication, read APIs are open.

```bash
AUTH_DISABLED=false
READ_AUTH_ENABLED=false
```

#### 2. Read Auth Enabled
Both write and read APIs require authentication.

```bash
AUTH_DISABLED=false
READ_AUTH_ENABLED=true
```

#### 3. Demo Mode
All APIs are open without authentication.

```bash
AUTH_DISABLED=true
```

### Authentication Flow

The service uses JWT tokens with ES256 signature verification. Tokens must be provided in the `Authorization` header:

```bash
curl -H "Authorization: Bearer <jwt_token>" http://localhost:8000/entity/
```

### Permission Resolution

Here's how permissions are resolved for each request:

```python
# Pseudo code for permission resolution

def resolve_write_permission(request):
    """Resolve permission for write operations (POST, PUT, PATCH, DELETE)"""
    
    # Step 1: Check demo mode
    if AUTH_DISABLED:
        return ALLOW  # Demo mode bypasses all auth
    
    # Step 2: Extract and validate JWT token
    token = extract_token_from_header(request.headers["Authorization"])
    if not token:
        return DENY  # No token provided
    
    try:
        payload = verify_jwt_signature(token, public_key, algorithm="ES256")
    except InvalidSignature:
        return DENY  # Invalid token
    except TokenExpired:
        return DENY  # Expired token
    
    # Step 3: Extract user info from payload
    user_id = payload.get("sub")  # User identifier
    permissions = payload.get("permissions", [])  # List of permissions
    is_admin = payload.get("is_admin", False)  # Admin flag
    
    # Step 4: Check permissions
    if is_admin:
        return ALLOW  # Admins bypass permission checks
    
    if "media_store_write" in permissions:
        return ALLOW  # User has write permission
    
    return DENY  # Insufficient permissions


def resolve_read_permission(request):
    """Resolve permission for read operations (GET)"""
    
    # Step 1: Check demo mode
    if AUTH_DISABLED:
        return ALLOW  # Demo mode bypasses all auth
    
    # Step 2: Check if read auth is enabled
    if not READ_AUTH_ENABLED:
        return ALLOW  # Read APIs are open by default
    
    # Step 3: Extract and validate JWT token
    token = extract_token_from_header(request.headers["Authorization"])
    if not token:
        return DENY  # Read auth enabled but no token
    
    try:
        payload = verify_jwt_signature(token, public_key, algorithm="ES256")
    except InvalidSignature:
        return DENY
    except TokenExpired:
        return DENY
    
    # Step 4: Extract user info and check permissions
    is_admin = payload.get("is_admin", False)
    permissions = payload.get("permissions", [])
    
    if is_admin:
        return ALLOW
    
    if "media_store_read" in permissions:
        return ALLOW
    
    return DENY
```

### JWT Payload Structure

Expected JWT payload format:

```json
{
  "sub": "user123",
  "permissions": ["media_store_read", "media_store_write"],
  "is_admin": false,
  "exp": 1700000000
}
```

### Required Permissions

- **`media_store_read`**: Required for GET operations when `READ_AUTH_ENABLED=true`
- **`media_store_write`**: Required for POST, PUT, PATCH, DELETE operations
- **Admin users** (`is_admin: true`): Bypass all permission checks

### Public Key Configuration

The service requires the authentication service's public key for JWT verification:

```bash
# Default path
PUBLIC_KEY_PATH=../data/public_key.pem

# Custom path
PUBLIC_KEY_PATH=/path/to/your/public_key.pem
```

The public key must be in PEM format (ES256 algorithm).
