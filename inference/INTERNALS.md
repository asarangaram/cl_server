# Inference Microservice - INTERNALS

## Overview

The Inference Microservice is a production-grade asynchronous ML inference system built with FastAPI that processes image analysis tasks (embedding extraction, face detection, face embedding) in a persistent queue with priority-based scheduling. It integrates with Qdrant for vector storage, MQTT for real-time event notifications, and supports horizontal scaling through distributed job queue processing.

**Core Responsibilities:**
- Accept inference job submissions via REST API
- Queue and process jobs with configurable priority
- Execute ML models (CLIP, RetinaFace, ArcFace) on images
- Store results in Qdrant vector database
- Notify clients of completion via MQTT/SSE
- Manage job lifecycle and error recovery

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        API Server (main.py)                    │
│  Receives requests → Routes → JobService → Database            │
└────────────────────────┬────────────────────────────────────────┘
                         │
                    Broadcasts via MQTT
                         │
┌────────────────────────▼────────────────────────────────────────┐
│              Background Worker (src/worker.py)                  │
│  Polls Queue → Dequeues Job → Fetches Image → Inference        │
└────────────────────────┬────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
    ┌────────┐      ┌──────────┐      ┌────────┐
    │ Qdrant │      │Media     │      │ Local  │
    │Vector  │      │ Store    │      │ Files  │
    │Store   │      │(Images)  │      │(Jobs)  │
    └────────┘      └──────────┘      └────────┘
```

---

## Directory Structure

```
inference/
├── src/
│   ├── __init__.py                  # FastAPI app initialization
│   ├── routes.py                    # REST API endpoints
│   ├── config.py                    # Environment configuration
│   ├── models.py                    # SQLAlchemy ORM models (jobs, queue)
│   ├── database.py                  # SQLAlchemy engine & sessions
│   ├── schemas.py                   # Pydantic request/response schemas
│   ├── queue.py                     # Priority queue implementation
│   ├── auth.py                      # JWT ES256 authentication
│   ├── broadcaster.py               # MQTT/SSE event publishing
│   ├── job_service.py               # Job CRUD & lifecycle management
│   ├── media_store_client.py        # HTTP client to media store
│   ├── worker.py                    # Background job processor
│   ├── qdrant_manager.py            # Qdrant Docker lifecycle mgmt
│   └── inferences/
│       ├── __init__.py
│       ├── image_embedding.py       # CLIP image embeddings (512-d)
│       ├── face_detection.py        # RetinaFace face detection
│       ├── face_embedding.py        # ArcFace face embeddings (512-d)
│       ├── image_store.py           # Qdrant image vector collection
│       └── face_store.py            # Qdrant face vector collection
├── alembic/                         # Database migrations
├── main.py                          # Uvicorn server entry point
├── pyproject.toml                   # Dependencies & metadata
└── alembic.ini                      # Alembic configuration
```

---

## Core Components

### 1. API Server (`src/__init__.py`, `main.py`)

**Purpose:** FastAPI application server that accepts inference job requests and provides status/result retrieval.

**Key Features:**
- CORS-enabled for cross-origin requests
- Async/await throughout for high concurrency
- Health check endpoint for orchestration
- Event streaming (SSE) support for real-time job updates

**Startup:**
```bash
# Development with hot reload
python main.py

# Production
uvicorn src:app --workers 4 --port 8001
```

**Port:** 8001

---

### 2. Routes & Endpoints (`src/routes.py`)

#### Public Endpoints (No Authentication)

| Endpoint | Method | Purpose | Response |
|----------|--------|---------|----------|
| `/health` | GET | Service health check | `{"status": "healthy"}` |
| `/job/{job_id}` | GET | Get job status and results | `JobResponse` |
| `/events` | GET | SSE event stream (if enabled) | Event stream |

#### Protected Endpoints (Requires `ai_inference_support` permission)

| Endpoint | Method | Purpose | Request | Response |
|----------|--------|---------|---------|----------|
| `/job/{task_type}` | POST | Create inference job | `JobCreateRequest` | `JobResponse` (201) |
| `/job/{job_id}` | DELETE | Cancel/delete job | — | `{"status": "deleted"}` |

#### Admin Endpoints (Requires `is_admin: true`)

| Endpoint | Method | Purpose | Query Params | Response |
|----------|--------|---------|--------------|----------|
| `/admin/stats` | GET | Service statistics | — | Statistics JSON |
| `/admin/cleanup` | DELETE | Bulk job deletion | `filters={"status": "error"}` | Cleanup summary |

**Task Types** (for POST /job/{task_type}):
- `image_embedding` - Extract 512-d CLIP embedding from image
- `face_detection` - Detect faces and return bounding boxes + landmarks
- `face_embedding` - Extract 512-d ArcFace embeddings per face

---

### 3. Job Model & Database (`src/models.py`, `src/database.py`)

**Three Core Tables:**

#### `jobs` Table
Stores metadata and results for each inference job.

```python
id (Integer, PK)
job_id (UUID, unique)
task_type (Enum: image_embedding|face_detection|face_embedding)
media_store_id (String) → reference to external service
status (Enum: pending|processing|completed|error|sync_failed)
created_at (Integer, ms) → when job was created
started_at (Integer, ms, nullable) → when processing began
completed_at (Integer, ms, nullable) → when processing completed
error_message (String, nullable) → error details if failed
retry_count (Integer) → number of retries attempted
max_retries (Integer) → maximum retries (default 3)
result (JSON, nullable) → result payload (varies by task_type)
created_by (String) → user ID from JWT token
```

**Status Lifecycle:**
```
pending → processing → completed
              ↓
           error (if max_retries exceeded)
              ↓
         sync_failed (media store unavailable)
```

#### `queue` Table
Priority-based queue for job processing.

```python
id (Integer, PK)
job_id (UUID, FK to jobs)
priority (Integer 0-10) → 10=highest, 0=lowest, default=5
enqueued_at (Integer, ms) → when added to queue
dequeued_at (Integer, ms, nullable) → when worker claimed it
worker_id (String, nullable) → which worker is processing

Indexes:
  - (priority DESC, enqueued_at ASC) → for efficient dequeuing
  - job_id (unique)
```

**Dequeue Strategy:** Workers fetch next job using:
```sql
SELECT * FROM queue
ORDER BY priority DESC, enqueued_at ASC
LIMIT 1
FOR UPDATE SKIP LOCKED
```

#### `media_store_sync_status` Table
Tracks synchronization of results back to media store.

```python
id (Integer, PK)
job_id (UUID, FK to jobs, unique)
sync_attempted_at (Integer, ms, nullable)
sync_completed_at (Integer, ms, nullable)
sync_status (Enum: pending|synced|failed)
sync_error (String, nullable)
retry_count (Integer)
next_retry_at (Integer, ms, nullable)
```

**Database Engine:** SQLite3 (ACID-compliant, local transactions, no network overhead)
**Location:** `../data/inference.db` (configurable via `DATABASE_URL`)

---

### 4. Queue & Scheduling (`src/queue.py`)

**Queue Type:** Priority-based persistent queue (SQLite-backed)

**Priority Levels:** 0-10 (10 is highest priority)
- Default priority: 5
- Customizable per job

**Dequeue Algorithm:**
1. Worker calls `Queue.dequeue(worker_id)` every 5 seconds (configurable)
2. Atomically selects highest-priority, oldest-enqueued job
3. Uses `FOR UPDATE SKIP LOCKED` to prevent concurrent workers from claiming same job
4. Updates `dequeued_at` timestamp and `worker_id`
5. Returns job_id or None if queue empty

**Features:**
- Crash-safe (survives worker crashes, job remains in queue)
- Multi-worker safe (row-level locking prevents duplicate processing)
- Persistent (survives service restarts)
- Configurable poll interval (`WORKER_POLL_INTERVAL=5` seconds)

---

### 5. Authentication (`src/auth.py`)

**Protocol:** JWT (JSON Web Tokens) with ES256 (ECDSA P-256) signatures

**Token Structure:**
```json
{
  "sub": "user_id",
  "ai_inference_support": true,  // permission
  "is_admin": false,              // admin flag
  "iat": 1700000000,
  "exp": 1700003600
}
```

**Verification Flow:**
1. Extract token from `Authorization: Bearer <token>` header
2. Load public key from `../data/public_key.pem`
3. Verify ES256 signature using public key
4. Validate expiration time (`exp` claim)
5. Extract claims for permission checking

**Permission Checks:**
- Job creation/deletion: requires `ai_inference_support: true`
- Admin endpoints: requires `is_admin: true`
- Health/events: public (no auth required)

**Demo Mode:** Set `AUTH_DISABLED=true` to bypass verification (uses mock payload)

---

### 6. Job Service (`src/job_service.py`)

**Responsibilities:**
- Create jobs with initial metadata
- Retrieve job status and results
- Update job status during processing
- Delete jobs and cleanup artifacts
- Track retry attempts

**Key Methods:**

```python
create_job(task_type, media_store_id, priority, user_id) → Job
  # Creates job, enqueues with priority, returns JobResponse

get_job(job_id) → Job | None
  # Retrieves job with current status and results

update_job_status(job_id, status, result=None, error=None)
  # Updates status, sets timestamps, stores result/error

delete_job(job_id)
  # Removes from queue, deletes artifacts, removes from DB

should_retry(job) → bool
  # Checks if retry_count < max_retries
```

---

### 7. Background Worker (`src/worker.py`)

**Purpose:** Continuously processes queued jobs in the background.

**Startup:**
```bash
python -m src.worker
```

**Main Event Loop:**
```
1. Poll queue every WORKER_POLL_INTERVAL seconds (default 5s)
2. If job found:
   a. Update status → "processing"
   b. Fetch image from media store
   c. Run inference (task_type-specific)
   d. Store results in Qdrant
   e. Update status → "completed"
   f. Broadcast MQTT event
   g. Return to step 1
3. If no job:
   - Sleep WORKER_POLL_INTERVAL seconds
   - Try again
```

**Error Handling:**
- If inference fails and `retry_count < max_retries`:
  - Increment retry_count
  - Re-enqueue job with same priority
- If max retries exceeded:
  - Set status → "error"
  - Store error_message
  - Broadcast MQTT `job_failed` event

**Signal Handling:**
- SIGTERM/SIGINT triggers graceful shutdown
- Waits for current job to complete before exiting
- Queued jobs remain in queue for next worker

**Multi-Worker Scaling:**
- Each worker instance has unique `worker_id` (UUID)
- `FOR UPDATE SKIP LOCKED` prevents processing same job twice
- Horizontal scaling: start multiple `python -m src.worker` processes

---

### 8. Media Store Integration (`src/media_store_client.py`)

**Purpose:** Fetch images from external media store service, post results back.

**Configuration:**
- `MEDIA_STORE_URL=http://localhost:8000`
- `MEDIA_STORE_STUB=false` (set true for testing without real service)

**Methods:**

```python
async get_image(media_store_id: str) → Image | str
  # Fetches image from GET /media/{media_store_id}
  # Returns PIL Image or base64 string in stub mode

async post_result(media_store_id: str, result_data: dict)
  # POSTs result to media store for persistence
  # Used for sync tracking (via media_store_sync_status)
```

**Stub Mode:** When `MEDIA_STORE_STUB=true`:
- Returns synthetic test images (random RGB numpy arrays)
- No actual HTTP requests made
- Useful for development and testing without running media store

**Failure Handling:**
- If image fetch fails: job marked as `sync_failed`, queued for retry
- Exponential backoff for retries (tracked in media_store_sync_status)

---

### 9. Qdrant Vector Store (`src/qdrant_manager.py`, `src/inferences/image_store.py`, `src/inferences/face_store.py`)

**Vector Database:** Qdrant (vector search engine)
**Protocol:** HTTP REST API
**Default URL:** `http://localhost:6333`

**QdrantManager (`src/qdrant_manager.py`):**
- Manages Docker lifecycle for Qdrant container
- Starts/stops Qdrant for testing
- Health checks before accepting jobs

**Collections:**

#### 1. `image_embeddings` (CLIP vectors)
```
Vector Size: 512 dimensions
Distance Metric: COSINE
Point Structure:
  id (Integer) → media_store_id
  vector (Float32[512]) → CLIP embedding
  payload {
    job_id (String)
    media_store_id (Integer)
  }
```

**Upsert:** When image_embedding task completes, stores point in collection

#### 2. `face_embeddings` (ArcFace vectors)
```
Vector Size: 512 dimensions
Distance Metric: COSINE
Point Structure:
  id (String) → "{job_id}-{face_index}"
  vector (Float32[512]) → ArcFace embedding (L2-normalized)
  payload {
    job_id (String)
    face_index (Integer)
    bbox (List[4]) → [x, y, width, height]
    confidence (Float) → detection confidence
  }
```

**Upsert:** When face_embedding task completes, stores point per detected face

**Usage Pattern:**
```python
# From VectorCore API (cl_ml_tools)
vector_core.add_file(image_path, collection_name="image_embeddings")
  # Automatically:
  # 1. Loads image
  # 2. Generates CLIP embedding
  # 3. Upserts to Qdrant
  # 4. Returns vector & metadata
```

---

### 10. ML Inference Implementations

#### CLIP Image Embeddings (`src/inferences/image_embedding.py`)

**Model:** `openai/clip-vit-base-patch32` (from HuggingFace)
**Output Dimension:** 512
**Normalization:** L2 normalized vectors
**Inference Method:** Via `cl_ml_tools.VectorCore` abstraction

**Input:** PIL Image or numpy RGB array (H, W, 3)
**Output:** Float32[512] L2-normalized vector

**Processing:**
```
Image → CLIP Processor (normalize, resize, tokenize)
     → CLIP Vision Encoder
     → Pooling
     → L2 Normalization
     → 512-d vector
```

**Device:** Auto-selects CUDA if available, falls back to CPU

#### RetinaFace Detection (`src/inferences/face_detection.py`)

**Library:** InsightFace (RetinaFace backbone)
**Input:** numpy RGB/BGR array (H, W, 3)
**Output:** List of detected faces with bounding boxes and landmarks

**Per-Face Output:**
```python
{
  "bbox": [x, y, width, height],      # bounding box
  "landmarks": [[x1, y1], [x2, y2], ...],  # 5 facial keypoints
  "confidence": 0.95,                  # detection confidence (0-1)
  "face_index": 0                      # 0-indexed face number
}
```

**Detection Sizes:** Configurable (default 640×640)
**Confidence Threshold:** Adjustable per implementation

#### ArcFace Embeddings (`src/inferences/face_embedding.py`)

**Library:** InsightFace (RetinaFace + ArcFace)
**Output Dimension:** 512
**Normalization:** L2 normalized
**Per-Image Requirement:** Expects exactly 1 face (cropped input)

**Processing Pipeline:**
```
Image → RetinaFace (detection & alignment)
     → ArcFace (512-d embedding generation)
     → L2 Normalization
     → 512-d vector
```

**Validation:** Raises error if ≠1 face detected (expects single cropped face)

---

## Request/Response Schemas

### Job Creation Request

```json
POST /job/image_embedding
{
  "media_store_id": "img_12345",
  "priority": 7
}
```

### Job Response

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "task_type": "image_embedding",
  "media_store_id": "img_12345",
  "status": "completed",
  "created_at": 1700000000000,
  "completed_at": 1700000005000,
  "result": {
    "embedding": [0.123, -0.456, ...],  // 512-d vector
    "vector_id": 12345
  },
  "created_by": "user_123"
}
```

**Status Values:**
- `pending` - Job created, awaiting processing
- `processing` - Worker actively processing
- `completed` - Successfully finished, result available
- `error` - Failed after max retries, error_message set
- `sync_failed` - Media store unavailable (pending retry)

---

## Event Broadcasting System

### MQTT Broadcasting (`src/broadcaster.py`)

**Protocol:** MQTTv5 (via paho-mqtt)
**Broker:** Configurable (default: `localhost:1883`)
**Topic:** `inference/events`

**Published Events:**

#### Job Completed
```json
{
  "event": "job_completed",
  "data": {
    "job_id": "550e8400-...",
    "task_type": "image_embedding",
    "media_store_id": "img_12345",
    "status": "completed",
    "result": {
      "embedding": [...],
      "vector_id": 12345
    }
  },
  "timestamp": 1700000005000
}
```

#### Job Failed
```json
{
  "event": "job_failed",
  "data": {
    "job_id": "550e8400-...",
    "status": "error",
    "error_message": "Image not found at media store",
    "retry_count": 3,
    "max_retries": 3
  },
  "timestamp": 1700000010000
}
```

### SSE Broadcasting (Alternative)

If `BROADCAST_TYPE=sse`, clients can subscribe to `/events` endpoint for server-sent events:
```
GET /events
Authorization: Bearer <token>

Response:
data: {"event": "job_completed", "data": {...}, "timestamp": ...}
data: {"event": "job_failed", "data": {...}, "timestamp": ...}
```

---

## Configuration & Environment Variables

### Database
```bash
DATABASE_DIR=../data                    # Data directory
DATABASE_URL=sqlite:///../data/inference.db  # SQLite path
```

### Storage
```bash
STORAGE_DIR=../data/inference/jobs      # Job artifact storage
```

### Authentication
```bash
PUBLIC_KEY_PATH=../data/public_key.pem  # ES256 public key
AUTH_DISABLED=false                     # Set true for demo mode
```

### Worker Configuration
```bash
WORKER_POLL_INTERVAL=5                  # Seconds between queue polls
WORKER_MAX_RETRIES=3                    # Max retries per job
```

### Vector Store
```bash
QDRANT_URL=http://localhost:6333        # Qdrant HTTP endpoint
```

### Broadcasting
```bash
BROADCAST_TYPE=mqtt                     # Options: mqtt|sse|none
MQTT_BROKER=localhost
MQTT_PORT=1883
MQTT_TOPIC=inference/events
```

### Media Store Integration
```bash
MEDIA_STORE_URL=http://localhost:8000   # Media store endpoint
MEDIA_STORE_STUB=false                  # Use stub for testing
```

### Logging
```bash
LOG_LEVEL=INFO                          # Log verbosity
```

---

## Deployment & Startup

### Development Setup

```bash
# 1. Install dependencies
cd inference
pip install -e .

# 2. Create data directories
mkdir -p ../data/inference/jobs

# 3. Run database migrations
alembic upgrade head

# 4. Start API server (Terminal 1)
python main.py

# 5. Start background worker (Terminal 2)
python -m src.worker

# 6. (Optional) Start Qdrant
docker run -p 6333:6333 qdrant/qdrant
```

### Production Deployment

```bash
# Using Gunicorn + Uvicorn workers
gunicorn src:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8001

# Multiple worker processes (separate instances)
python -m src.worker &
python -m src.worker &
python -m src.worker &
```

### Docker Deployment

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY inference/ .
RUN pip install -e .
RUN alembic upgrade head
CMD ["uvicorn", "src:app", "--host", "0.0.0.0", "--port", "8001"]
```

---

## Error Handling & Resilience

### Job Failures & Retries

**Automatic Retry Logic:**
1. Job fails during inference
2. If `retry_count < max_retries`:
   - Increment retry_count
   - Re-enqueue with same priority
   - Status remains "processing"
3. If `retry_count >= max_retries`:
   - Set status → "error"
   - Store error_message
   - Broadcast job_failed event
   - Do NOT re-queue

**Configuration:**
- `WORKER_MAX_RETRIES=3` (configurable)
- Retries use exponential backoff in media store sync

### Media Store Sync Failures

**Tracking Table:** `media_store_sync_status`

**Sync Retry Algorithm:**
```
1. After job completion, attempt to POST result to media store
2. If POST fails:
   - Mark sync_status = "failed"
   - Store sync_error message
   - Calculate next_retry_at = now + backoff(retry_count)
   - Set sync_attempted_at timestamp
3. Admin cleanup job periodically retries sync_failed jobs
4. After max sync retries, mark as permanently failed
```

### Graceful Shutdown

**Worker Process:**
- Registers signal handlers (SIGTERM, SIGINT)
- On signal received:
  - Stops polling queue
  - Allows current job to complete
  - Exits with code 0
  - Job remains in queue for next worker

**Persistent Queue:**
- Unclaimed jobs remain in queue
- Dequeued but unfinished jobs (worker crashed):
  - `dequeued_at` stays set but `completed_at` null
  - Admin cleanup can reset these jobs

---

## Performance Characteristics

### Throughput

**Single Worker:** ~2-3 jobs/minute (assuming 20-30s per inference + network latency)
**Bottlenecks:**
- CLIP model inference: ~10-15ms per image
- Face detection: ~20-50ms per image
- Face embedding: ~15-25ms per face
- I/O (image download/upload): ~100-500ms per job

### Scalability

**Horizontal Scaling:** Add more worker processes
- No shared state (SQLite handles concurrency)
- Each worker independently polls queue
- `FOR UPDATE SKIP LOCKED` prevents duplicate processing

**Vertical Scaling:** Increase model batch sizes (future optimization)

### Resource Usage

**Per Inference:**
- CLIP: ~1.2GB VRAM
- RetinaFace: ~800MB VRAM
- ArcFace: ~600MB VRAM
- GPU highly recommended; CPU fallback available

**Database:**
- SQLite keeps all metadata in-memory (fast queries)
- No network latency for job queue operations

---

## Recent Development Status

**Latest Feature (commit 5e02c1a):**
- CLIP image embedding extraction
- RetinaFace face detection + landmarks
- ArcFace face embeddings
- Qdrant vector storage integration
- Persistent priority-based job queue
- MQTT event broadcasting

**Work in Progress (commit 4c0018d, branch: inference_service):**
- MQTT integration refinements
- Testing and validation

**Modified Files (uncommitted):**
- `src/inferences/image_embedding.py` - Working changes
- `src/worker.py` - Working changes
- `test_mqtt_complete.py` - Integration test

---

## Security Considerations

### Authentication & Authorization

- **ES256 JWT Verification:** All protected endpoints validate token signature
- **Permission-Based Access:** `ai_inference_support` claim required for inference jobs
- **Admin Operations:** Separate `is_admin` flag for cleanup/admin endpoints
- **Demo Mode:** `AUTH_DISABLED=true` only for development

### Data Privacy

- **Local Storage:** Job artifacts stored locally in `STORAGE_DIR` (no cloud)
- **Temporary Files:** Cleaned up after job completion (deletion endpoint)
- **MQTT Topics:** Consider network encryption (TLS for production)

### Input Validation

- Job creation requires valid `task_type` (enum validation)
- Priority bounded to 0-10
- Media store ID validated as string

---

## Testing Utilities

### MQTT Testing (`test_mqtt_complete.py`)

End-to-end test of MQTT broadcasting and job completion notifications.

```bash
python test_mqtt_complete.py
```

### MQTT Subscriber (`mqtt_subscriber.py`)

Standalone utility to listen for events on inference/events topic:

```bash
python -m src.mqtt_subscriber
```

---

## Dependencies Summary

| Package | Purpose |
|---------|---------|
| FastAPI | REST API framework |
| Uvicorn | ASGI server |
| SQLAlchemy | ORM & database |
| Alembic | Database migrations |
| Pydantic | Validation |
| python-jose | JWT handling |
| httpx | Async HTTP client |
| paho-mqtt | MQTT client |
| PyTorch | Deep learning |
| transformers | HuggingFace models (CLIP) |
| insightface | RetinaFace, ArcFace |
| onnxruntime | ONNX inference |
| Pillow | Image processing |
| numpy | Array operations |
| cl_ml_tools | ML abstractions (VectorCore, MLInference) |

---

## API Documentation

Interactive API documentation available at: `http://localhost:8001/docs`

Provides Swagger UI for:
- Endpoint exploration
- Request/response schemas
- Try-it-out functionality
- Authentication testing

---

## Related Documentation

- **User Guide:** See `README.md` for usage examples
- **ML Integration:** See `ML_INFERENCE_GUIDE.md` for model details
- **Database Migrations:** See `alembic/` directory for schema evolution
