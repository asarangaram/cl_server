# CoLAN Media Store Internals

This document outlines the internal design choices, architecture, and potential enhancements for the CoLAN Media Store service.

## Architecture Overview

The service is built using a standard FastAPI microservice architecture with organized package structure:

- **Framework**: FastAPI (ASGI)
- **Database**: SQLite (for simplicity/portability) with SQLAlchemy ORM
- **Validation**: Pydantic v2
- **Versioning**: SQLAlchemy-Continuum
- **Metadata**: clmediakit (wrapping exiftool)

### Package Structure

```
server/
├── config.py              # Application-wide configuration
├── __init__.py           # FastAPI app initialization
├── api/                  # API route handlers
│   ├── __init__.py
│   └── entity_routes.py  # Entity CRUD endpoints
├── core/                 # Infrastructure & utilities
│   ├── __init__.py
│   ├── database.py       # Database connection & session
│   ├── versioning.py     # SQLAlchemy-Continuum setup
│   └── file_storage.py   # File storage service
├── models/               # Data models & schemas
│   ├── __init__.py
│   ├── models.py         # SQLAlchemy ORM models
│   └── schemas.py        # Pydantic request/response schemas
└── services/             # Business logic layer
    ├── __init__.py
    └── entity_service.py # Entity operations
```

**Design Rationale:**
- `api/` - Route handlers separated from business logic
- `core/` - Infrastructure components (database, storage, versioning)
- `models/` - All data structures (ORM models + Pydantic schemas)
- `services/` - Business logic isolated from HTTP concerns
- `config.py` - Top-level for application-wide settings

### Data Storage

**Production Data Location:**
- Database: `../data/media_store.db`
- Media files: `../data/media_store/`

All persistent data is stored outside the `media_store/` directory in `../data/` for cleaner project structure and easier backup management.

**Environment Variables:**
You can override the default paths using environment variables:
- `DATABASE_DIR` - Directory for database file (default: `../data`)
- `DATABASE_URL` - Full database URL (default: `sqlite:///../data/media_store.db`)
- `MEDIA_STORAGE_DIR` - Directory for media files (default: `../data/media_store`)

Example:
```bash
export DATABASE_DIR="/var/lib/media-store"
export MEDIA_STORAGE_DIR="/var/lib/media-store/files"
```

## Design Choices

### 1. Entity Versioning
We use **SQLAlchemy-Continuum** for automatic entity versioning.
- **Why**: It automatically tracks changes to all fields without manual history table management.
- **Implementation**: 
  - `make_versioned()` is called before model imports in `server/core/versioning.py`.
  - `configure_mappers()` is called in `server/__init__.py`.
  - Versions are accessed via the `versions` relationship on the `Entity` model.
- **Import Order**: Critical that `versioning` is imported before `models` to ensure proper setup.

### 2. Pagination
We implemented **Offset/Limit** pagination.
- **Why**: Standard, easy to implement, and sufficient for the expected dataset size.
- **Details**: 
  - Default page size: 20
  - Max page size: 100
  - Returns `PaginationMetadata` with total counts and navigation flags.

### 3. File Storage
Files are stored locally using a **Time-Based Directory Structure**.
- **Format**: `media_files/YYYY/MM/DD/{md5}.{extension}`
- **Why**: 
  - Prevents single directories from becoming too large (filesystem limits).
  - Organizes files chronologically.
  - MD5 naming prevents overwrites of different files with the same name.
  - Extension is preserved for proper file handling.

### 4. Duplicate Detection
We use **MD5 Hashing** for duplicate detection.
- **Why**: Fast and reliable for detecting exact duplicates.
- **Behavior**: 
  - Calculated on upload.
  - Checked against existing entities.
  - Rejects upload if hash exists (HTTP 409).

### 5. Deletion Strategy
We support both **Hard** and **Soft** deletes.
- **Hard Delete**: `DELETE /entity/{id}` permanently removes the entity and its file.
- **Soft Delete**: `PATCH /entity/{id}` with `is_deleted=True` marks the entity as deleted.
- **Restore**: `PATCH /entity/{id}` with `is_deleted=False` restores the entity.

## Missing Features & Enhancements

### High Priority
1. **Video Duration Extraction**: 
   - Current implementation supports it, but we lack test coverage due to missing video test files.

### Medium Priority
1. **Filtering & Search**: 
   - Endpoints accept `filter_param` and `search_query`, but the logic is not implemented in `EntityService`.

### Low Priority
1. **Async File I/O**: 
   - File operations currently use synchronous `open()`. For high throughput, `aiofiles` should be considered.
2. **Thumbnail Generation**: 
   - No built-in thumbnail generation for large images or videos.
