# AI Inference Microservice

Asynchronous AI inference service for image processing with face detection and embedding generation.

## Features

- ✅ **Priority-based Job Queue**: SQLite-backed persistent queue with 0-10 priority levels
- ✅ **JWT Authentication**: ES256 signature verification with `ai_inference_support` permission
- ✅ **Asynchronous Processing**: Background worker with graceful shutdown
- ✅ **Three Inference Tasks**:
  - Image Embedding (512-d vectors)
  - Face Detection (bounding boxes, landmarks, crops)
  - Face Embedding (per-face 512-d vectors)
- ✅ **Persistent Storage**: SQLite database with 3 tables (jobs, queue, sync_status)
- ✅ **Result Storage**: JSON results in database + binary files on disk

## Setup

### Prerequisites

- Python 3.9+
- Virtual environment (pyenv recommended)

### Installation

```bash
# Activate virtual environment
pyenv activate media_repo_env

# Install dependencies
cd inference
pip install -e .

# Run database migrations
alembic upgrade head
```

### Configuration

Environment variables (all optional):

```bash
# Database
export DATABASE_DIR=../data
export DATABASE_URL=sqlite:///../data/inference.db

# Storage
export STORAGE_DIR=../data/inference/jobs

# Authentication
export PUBLIC_KEY_PATH=../data/public_key.pem
export AUTH_DISABLED=false  # Set to 'true' for demo mode

# Worker
export WORKER_POLL_INTERVAL=1  # seconds
export WORKER_MAX_RETRIES=3

# Media Store
export MEDIA_STORE_URL=http://localhost:8000
export MEDIA_STORE_STUB=true  # Set to 'false' for real media_store integration

# Logging
export LOG_LEVEL=INFO
```

## Running the Service

### API Server

```bash
# Development (with hot reload)
uvicorn main:app --reload --port 8001

# Production
uvicorn main:app --host 0.0.0.0 --port 8001
```

The API will be available at `http://localhost:8001`.  
Interactive documentation: `http://localhost:8001/docs`.

### Background Worker

In a separate terminal:

```bash
pyenv activate media_repo_env
cd inference
python -m src.worker
```

## API Endpoints

### Job Management

#### Create Job
```http
POST /job/{task_type}
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "media_store_id": "string",
  "priority": 5  // Optional: 0-10, default 5
}
```

**Task Types**: `image_embedding`, `face_detection`, `face_embedding`

**Response (201)**:
```json
{
  "job_id": "uuid",
  "task_type": "image_embedding",
  "media_store_id": "string",
  "status": "pending",
  "priority": 5,
  "created_at": 1700000000000
}
```

#### Get Job Status
```http
GET /job/{job_id}
```

No authentication required.

**Response (200)**:
```json
{
  "job_id": "uuid",
  "task_type": "image_embedding",
  "status": "completed",
  "result": {
    "embedding_dimension": 512,
    "embedding_path": "jobs/{job_id}/embedding.bin"
  }
}
```

#### Delete Job
```http
DELETE /job/{job_id}
Authorization: Bearer <jwt_token>
```

Requires `ai_inference_support` permission.

### Admin Endpoints

#### Get Statistics
```http
GET /admin/stats
Authorization: Bearer <jwt_token>
```

Requires `is_admin: true` in JWT.

#### Cleanup
```http
DELETE /admin/cleanup
Authorization: Bearer <jwt_token>
```

Requires `is_admin: true` in JWT.

### Health Check
```http
GET /health
```

No authentication required.

## Authentication

### Required Permission

**`ai_inference_support`**: Required for:
- Creating jobs (`POST /job/{task_type}`)
- Deleting jobs (`DELETE /job/{job_id}`)

### JWT Token Format

```json
{
  "sub": "user_id",
  "permissions": ["ai_inference_support"],
  "is_admin": false,
  "exp": 1700000000
}
```

### Demo Mode

For testing without authentication:

```bash
export AUTH_DISABLED=true
```

## Database Schema

### Tables

1. **jobs** - Job metadata, status, and results (JSON)
2. **queue** - Priority-based persistent queue
3. **media_store_sync_status** - Sync tracking with media_store

### Priority Levels

- `10`: Critical/Urgent
- `5`: Normal (default)
- `0`: Low priority/Background

Jobs are processed by highest priority first, then FIFO within the same priority level.

## File Storage

```
data/inference/jobs/
└── {job_id}/
    ├── embedding.bin           # Image embedding (NumPy binary)
    └── faces/
        ├── 0.jpg              # Face crop
        ├── 0.bin              # Face embedding
        ├── 1.jpg
        └── 1.bin
```

## Result Formats

### Image Embedding
```json
{
  "embedding_dimension": 512,
  "embedding_path": "jobs/{job_id}/embedding.bin"
}
```

### Face Detection
```json
{
  "faces": [
    {
      "face_index": 0,
      "bbox": {"x": 100.5, "y": 150.2, "width": 80.3, "height": 90.1},
      "confidence": 0.99,
      "landmarks": {"left_eye": [120, 160], ...},
      "crop_path": "jobs/{job_id}/faces/0.jpg"
    }
  ]
}
```

### Face Embedding
```json
{
  "faces": [
    {
      "face_index": 0,
      "bbox": {"x": 100.5, "y": 150.2, "width": 80.3, "height": 90.1},
      "confidence": 0.99,
      "embedding_dimension": 512,
      "embedding_path": "jobs/{job_id}/faces/0.bin",
      "crop_path": "jobs/{job_id}/faces/0.jpg"
    }
  ]
}
```

## Development

### Running Tests

```bash
pytest
```

### Database Migrations

```bash
# Create new migration
alembic revision --autogenerate -m "description"

# Apply migrations
alembic upgrade head

# Rollback
alembic downgrade -1
```

## Architecture

- **FastAPI**: REST API framework
- **SQLAlchemy**: ORM and database toolkit
- **Alembic**: Database migrations
- **SQLite**: Embedded ACID-compliant database
- **python-jose**: JWT validation (ES256)
- **NumPy**: Embedding storage
- **Pillow**: Image processing

## Stub Mode

Currently, the inference functions are stubbed and return random data:
- Image embeddings: Random 512-d vectors
- Face detection: 1-3 random faces with realistic bboxes
- Face embeddings: Random 512-d vectors per face

To integrate real ML models, replace the functions in `src/inference_stubs.py`.

## Next Steps

- [ ] Implement broadcasting system (SSE/MQTT)
- [ ] Add comprehensive tests
- [ ] Integrate real ML models
- [ ] Add Prometheus metrics
- [ ] Docker support
- [ ] Production deployment guide

## License

[Your License Here]
