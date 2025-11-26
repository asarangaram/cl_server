# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a multi-service microservices architecture with three main services:

1. **Media Store Service** (port 8000): FastAPI microservice for managing media entities with metadata extraction, versioning, and duplicate detection. Uses SQLAlchemy with versioning via sqlalchemy-continuum.

2. **Inference Service** (port 8001): Asynchronous inference service for image and face processing with job queue management. Includes integration with Qdrant for vector storage and media store client for cross-service communication.

3. **Authentication Service**: FastAPI service handling user authentication, permissions, and JWT token generation. Provides OAuth2 password flow authentication.

## Architecture Patterns

### Microservices Layout
```
services/
├── media_store/          # Media entity management
│   ├── main.py          # Entry point (uvicorn on port 8000)
│   └── src/             # Core application code
│       ├── models.py    # SQLAlchemy models with versioning
│       ├── routes.py    # API endpoints
│       ├── service.py   # Business logic
│       ├── database.py  # DB session management
│       └── auth.py      # Permission checks
├── inference/           # AI inference tasks
│   ├── main.py         # Entry point (uvicorn on port 8001)
│   └── src/
│       ├── job_service.py     # Job queue and execution
│       ├── queue.py           # Queue management
│       ├── worker.py          # Background worker processes
│       └── qdrant_manager.py  # Vector database integration
└── authentication/      # User and permission management
    ├── main.py
    └── src/
        ├── service.py   # UserService for CRUD operations
        ├── models.py    # User, UserPermission models
        └── routes.py    # OAuth2 endpoints
```

### Database Structure
- Each service has its own SQLAlchemy database with separate `database.py`
- **Critical Import Order**: Versioning modules must be imported BEFORE models to activate SQLAlchemy-Continuum:
  ```python
  from . import versioning  # Must be first
  from .models import Base  # Then models
  ```
- Media Store uses sqlalchemy-continuum for entity versioning with automatic version history tracking
- Alembic migrations exist in each service's `alembic/` directory

### Authentication & Authorization
- OAuth2 PasswordBearer scheme with JWT tokens
- Tokens created by authentication service, validated by other services
- Permission-based access control: users have permission strings stored in `UserPermission` table
- Two main decorators in each service:
  - `get_current_user_with_read_permission(permission_name)`
  - `get_current_user_with_write_permission(permission_name)`

### API Patterns
- Media Store: RESTful entity CRUD with versioning support (GET /entity/, POST /entity/, PUT /entity/{id}, etc.)
- Inference Service: Job-based async operations (POST /job/{task_type})
- Pagination implemented with page/page_size query parameters
- All services use FastAPI with CORS enabled

## Development Commands

### Running Services
```bash
# Media Store (port 8000, auto-reload enabled)
python services/media_store/main.py

# Inference Service (port 8001)
python services/inference/main.py

# Authentication Service (port 8002)
python services/authentication/main.py
```

### Testing
```bash
# Run all tests
pytest tests/ -v

# Run specific test module
pytest tests/media_store/test_entity_crud.py -v

# Run single test
pytest tests/media_store/test_entity_crud.py::TestEntityCRUD::test_create_entity -v

# Run by marker
pytest -m media_store -v          # All media_store tests
pytest -m integration -v           # Integration tests
pytest -m unit -v                  # Unit tests only

# Run with output
pytest tests/ -v -s               # Show print statements
pytest tests/ -v --tb=short       # Short traceback format
```

### Configuration
- `pytest.ini` at root defines test discovery and markers
- Each service has its own `pyproject.toml` with dependencies
- Services use environment-based configuration (see `services/*/src/config.py`)
- Test database uses in-memory SQLite with StaticPool for thread safety

## Testing Infrastructure

### Test Structure
- Centralized test directory at root: `tests/media_store/`, `tests/inference/`, `tests/authentication/`
- `conftest.py` provides shared fixtures: `test_engine`, `test_client`, database session management
- Test images stored in `tests/images/` directory

### Key Fixtures
- `test_engine`: In-memory SQLite database with proper versioning setup
- `test_client`: FastAPI TestClient for HTTP testing
- Database fixtures handle setup/teardown with proper model initialization

### Test Markers
- `@pytest.mark.unit`: Fast tests without external services
- `@pytest.mark.integration`: Tests requiring external services
- `@pytest.mark.media_store`: Media store specific tests
- `@pytest.mark.inference`: Inference service tests
- `@pytest.mark.auth`: Authentication tests
- `@pytest.mark.broadcaster`: Event broadcasting tests

## Important Implementation Notes

### Database Import Order (CRITICAL)
The media_store service uses sqlalchemy-continuum for automatic versioning. The versioning module MUST be imported before models:
- In `database.py`: Import versioning before Base
- In `conftest.py`: Call `configure_mappers()` after importing models but before `create_all()`
- This is documented in inline comments marked "CRITICAL"

### Service Independence
- Media Store doesn't depend on other services
- Inference Service can query Media Store via `media_store_client.py`
- Services authenticate using shared JWT validation logic

### Error Handling
- Media Store routes preserve HTTPException structure for client compatibility
- Services use consistent error response format: `{"detail": "error message"}`

## Dependencies
- **FastAPI & Uvicorn**: Web framework and server
- **SQLAlchemy 2.0+**: ORM with Alembic migrations
- **sqlalchemy-continuum**: Automatic entity versioning
- **python-jose + cryptography**: JWT token handling
- **httpx**: HTTP client for inter-service communication
- **pytest**: Test framework
- **clmediakit**: Custom media processing library (git dependency)

## Git Workflow
Current branch: `refactor_folder_structure` (recent reorganization of tests and services into root-level directories)
Recent work focused on consolidating tests and standardizing service structure.
