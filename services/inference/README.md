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
- ✅ **Vector Storage**: Qdrant integration for embedding similarity search

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

# Qdrant Vector Storage
export QDRANT_URL=http://localhost:6333

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
    "stored_in_vector_db": true,
    "collection": "image_embeddings",
    "point_id": 123
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

---

## Workflows

This section explains the complete workflow for each inference task type from the client's perspective, including how vectors are stored in Qdrant.

### Workflow 1: Image Embedding

Image embedding generates a 512-dimensional vector representation of an entire image using the CLIP model, which is stored in Qdrant for similarity search.

#### Overview

```
Client Application
    ↓
    └─→ POST /job/image_embedding
         (Create job with media_store_id)

Job Queue → Worker Process
    ↓
    ├─→ 1. Fetch image from media_store
    ├─→ 2. Run CLIP ViT-B/32 inference
    ├─→ 3. Get 512-d normalized embedding
    ├─→ 4. Store in Qdrant
    └─→ 5. Update job status: completed

Client polls GET /job/{job_id}
    ↓
    └─→ Result: {
        "embedding_dimension": 512,
        "stored_in_vector_db": true,
        "collection": "image_embeddings",
        "point_id": 123
        }
```

#### Step 1: Create Job

```bash
curl -X POST http://localhost:8001/job/image_embedding \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "media_store_id": "image-789",
    "priority": 5
  }'
```

**Response (201 Created):**
```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "task_type": "image_embedding",
  "media_store_id": "image-789",
  "status": "pending",
  "priority": 5,
  "created_at": 1700000000000
}
```

#### Step 2: Worker Processing

**Internal Process:**
1. **Fetch Image** (worker.py:172)
   - Retrieves image from media_store using `media_store_id`
   - Returns PIL Image object

2. **Generate Embedding** (worker.py:229-264)
   ```
   CLIP ViT-B/32 model processes the image
   Output: 512-dimensional normalized vector
   Each dimension is a float32 value between -1.0 and 1.0
   ```

3. **Store in Qdrant** (worker.py:245-254)
   ```
   VectorCore.add_file(
     id=123                          # Point ID from media_store_id
     data=image                      # PIL Image
     payload={
       "job_id": "550e8400...",
       "media_store_id": 123,
       "task_type": "image_embedding"
     }
     force=True                      # Always update
   )
   ```

4. **Qdrant Storage**
   ```
   Collection: "image_embeddings"
   Point ID: 123
   Vector: [0.123, -0.456, 0.789, ..., 0.234]  (512 values, normalized)
   Payload: {job_id, media_store_id, task_type}
   Distance Metric: Cosine
   ```

#### Step 3: Poll Job Status

```bash
# While processing
curl -X GET http://localhost:8001/job/550e8400-e29b-41d4-a716-446655440000
```

**Response (processing):**
```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "processing",
  "started_at": 1700000005000
}
```

**Response (completed):**
```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "completed",
  "completed_at": 1700000010000,
  "result": {
    "embedding_dimension": 512,
    "stored_in_vector_db": true,
    "collection": "image_embeddings",
    "point_id": 123
  }
}
```

#### Step 4: Use the Embedding

Once stored in Qdrant, you can perform similarity search:

```python
from qdrant_client import QdrantClient

client = QdrantClient(url="http://localhost:6333")

# Get embedding for query image (same CLIP model)
query_embedding = generate_clip_embedding(query_image)

# Find similar images
results = client.search(
    collection_name="image_embeddings",
    query_vector=query_embedding,
    limit=10,
    score_threshold=0.7  # Cosine similarity threshold
)

# Results structure:
# [{
#   "id": 123,
#   "score": 0.89,
#   "payload": {
#     "job_id": "550e8400...",
#     "media_store_id": 123,
#     "task_type": "image_embedding"
#   }
# }, ...]
```

---

### Workflow 2: Face Detection

Face detection identifies and localizes faces in an image, returning bounding boxes, landmarks, and confidence scores. Face detection results are returned in the job result but are NOT stored in Qdrant.

#### Overview

```
Client Application
    ↓
    └─→ POST /job/face_detection
         (Create job with media_store_id)

Job Queue → Worker Process
    ↓
    ├─→ 1. Fetch image from media_store
    ├─→ 2. Run face detection model
    ├─→ 3. Get faces with bboxes & landmarks
    ├─→ 4. Extract face crops
    ├─→ 5. Upload results to media_store
    └─→ 6. Update job status: completed

Client polls GET /job/{job_id}
    ↓
    └─→ Result: {
        "faces": [
          {
            "face_index": 0,
            "bbox": {...},
            "landmarks": {...},
            "confidence": 0.99
          }
        ],
        "face_count": 1
        }
```

#### Step 1: Create Job

```bash
curl -X POST http://localhost:8001/job/face_detection \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "media_store_id": "photo-456",
    "priority": 8
  }'
```

**Response (201 Created):**
```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440001",
  "task_type": "face_detection",
  "media_store_id": "photo-456",
  "status": "pending",
  "priority": 8,
  "created_at": 1700000000000
}
```

#### Step 2: Worker Processing

**Internal Process:**
1. **Fetch Image** (worker.py:172)
   - Retrieves image from media_store

2. **Detect Faces** (worker.py:266-289)
   ```
   Run face detection model (YOLO/RetinaFace based)
   Returns: List of detected faces with:
   - Bounding box (x, y, width, height)
   - Confidence score (0-1)
   - Facial landmarks (5 points: eyes, nose, mouth corners)
   - Face crop image
   ```

3. **Extract Face Crops and Upload**
   - For each detected face, extract the bounding box region
   - Save face crops as images
   - Upload results to media_store

4. **Return Results** (worker.py:286-289)
   ```json
   {
     "faces": [
       {
         "face_index": 0,
         "bbox": {"x": 100.5, "y": 150.2, "width": 80.3, "height": 90.1},
         "confidence": 0.99,
         "landmarks": {...}
       }
     ],
     "face_count": 1
   }
   ```

#### Step 3: Poll Job Status

```bash
curl -X GET http://localhost:8001/job/550e8400-e29b-41d4-a716-446655440001
```

**Response (completed):**
```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440001",
  "status": "completed",
  "result": {
    "faces": [
      {
        "face_index": 0,
        "bbox": {
          "x": 100.5,
          "y": 150.2,
          "width": 80.3,
          "height": 90.1
        },
        "confidence": 0.99,
        "landmarks": {
          "left_eye": [120, 160],
          "right_eye": [140, 160],
          "nose": [130, 175],
          "left_mouth": [125, 190],
          "right_mouth": [135, 190]
        }
      }
    ],
    "face_count": 1
  }
}
```

#### Step 4: Use Face Detection Results

The detection results can be used to:
- Draw bounding boxes on images
- Crop faces for separate processing
- Feed into face embedding or recognition systems
- Build face detection analytics
- Extract individual faces for other tasks

---

### Workflow 3: Face Embedding

Face embedding generates 512-dimensional vectors for each detected face in an image, storing them in Qdrant for face-level similarity search and recognition.

#### Overview

```
Client Application
    ↓
    └─→ POST /job/face_embedding
         (Create job with media_store_id)

Job Queue → Worker Process
    ↓
    ├─→ 1. Fetch image from media_store
    ├─→ 2. Detect all faces in image
    ├─→ 3. For each face:
    │   ├─→ Extract face crop
    │   ├─→ Generate 512-d embedding
    │   └─→ Store in Qdrant (unique point ID per face)
    └─→ 4. Update job status: completed

Client polls GET /job/{job_id}
    ↓
    └─→ Result: {
        "faces": [
          {
            "face_index": 0,
            "bbox": {...},
            "embedded_in_vector_db": true,
            "point_id": 456000,
            "embedding_dimension": 512
          }
        ],
        "face_count": 1
        }
```

#### Step 1: Create Job

```bash
curl -X POST http://localhost:8001/job/face_embedding \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "media_store_id": "group-photo-123",
    "priority": 5
  }'
```

**Response (201 Created):**
```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440002",
  "task_type": "face_embedding",
  "media_store_id": "group-photo-123",
  "status": "pending",
  "priority": 5,
  "created_at": 1700000000000
}
```

#### Step 2: Worker Processing

**Internal Process:**
1. **Fetch Image** (worker.py:172)
   - Retrieves image from media_store

2. **Get All Faces with Embeddings** (worker.py:291-316)
   ```
   For each detected face:
   1. Extract face crop
   2. Run face embedding model (same as CLIP but for faces)
   3. Get 512-d normalized embedding

   Returns: List of faces with embeddings
   ```

3. **Store Each Face Embedding in Qdrant** (worker.py:318-339)
   ```
   For face at index 0 with media_store_id 123:
   Point ID = 123 * 1000 + 0 = 123000

   For face at index 1:
   Point ID = 123 * 1000 + 1 = 123001
   ```

4. **Qdrant Storage (Multiple Points)**
   ```
   Collection: "faces"

   Point 1:
   ├─ ID: 123000
   ├─ Vector: [0.123, -0.456, ..., 0.234]  (512-d, normalized)
   └─ Payload: {face_index: 0, bbox, confidence, landmarks, ...}

   Point 2:
   ├─ ID: 123001
   ├─ Vector: [0.456, 0.123, ..., -0.567]  (512-d, normalized)
   └─ Payload: {face_index: 1, bbox, confidence, landmarks, ...}
   ```

#### Step 3: Poll Job Status

```bash
curl -X GET http://localhost:8001/job/550e8400-e29b-41d4-a716-446655440002
```

**Response (completed, multiple faces):**
```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440002",
  "status": "completed",
  "result": {
    "faces": [
      {
        "face_index": 0,
        "bbox": {
          "x": 100.5,
          "y": 150.2,
          "width": 80.3,
          "height": 90.1
        },
        "confidence": 0.99,
        "embedding_dimension": 512,
        "point_id": 123000,
        "stored_in_vector_db": true
      },
      {
        "face_index": 1,
        "bbox": {
          "x": 250.0,
          "y": 160.0,
          "width": 75.0,
          "height": 85.0
        },
        "confidence": 0.97,
        "embedding_dimension": 512,
        "point_id": 123001,
        "stored_in_vector_db": true
      }
    ],
    "face_count": 2,
    "stored_in_vector_db": true
  }
}
```

#### Step 4: Use Face Embeddings

Once stored in Qdrant, you can perform face-level similarity search:

```python
from qdrant_client import QdrantClient

client = QdrantClient(url="http://localhost:6333")

# Get embedding for query face (same face embedding model)
query_face_embedding = generate_face_embedding(query_face_image)

# Find similar faces
results = client.search(
    collection_name="faces",
    query_vector=query_face_embedding,
    limit=10,
    score_threshold=0.8  # High threshold for face matching
)

# Results contain:
# [{
#   "id": 123000,
#   "score": 0.95,
#   "payload": {
#     "job_id": "550e8400...",
#     "face_index": 0,
#     "media_store_id": 123,
#     "bbox": {...},
#     "confidence": 0.99
#   }
# }, ...]

# Use results for:
# - Face recognition/identification
# - Finding duplicate face photos
# - Building face galleries
# - Person-based photo organization
```

---

## Comparison: Image Embedding vs Face Detection vs Face Embedding

| Aspect | Image Embedding | Face Detection | Face Embedding |
|--------|-----------------|----------------|----------------|
| **Input** | Entire image | Entire image | Entire image |
| **Output** | 1 vector (512-d) | Bounding boxes + landmarks | N vectors (one per face) |
| **Storage** | Qdrant (vector DB) | JSON in DB | Qdrant (vector DB) |
| **Use Case** | Image similarity search | Locate faces in photos | Face recognition/matching |
| **Point ID** | media_store_id | N/A | media_store_id * 1000 + face_index |
| **Collection** | image_embeddings | N/A | faces |
| **Multiple Results** | No (1 per image) | Yes (multiple faces) | Yes (one per face) |
| **Searchable** | Yes (cosine similarity) | No (structured data) | Yes (cosine similarity) |

---

## Queue Priority System

Jobs are processed based on priority (0-10, higher = more urgent):

```
Priority 10: Critical/Urgent    ▲
Priority 8:  High                │
Priority 5:  Normal (default)    │ Process order
Priority 2:  Low                 │
Priority 0:  Background/Batch    ▼
```

**Within same priority:** FIFO (First In, First Out)

Example:
```
Queue:
1. Job A (priority 5) - created at T0
2. Job B (priority 8) - created at T1
3. Job C (priority 5) - created at T2
4. Job D (priority 10) - created at T3

Processing order:
1. Job D (priority 10)
2. Job B (priority 8)
3. Job A (priority 5, older than C)
4. Job C (priority 5, newer than A)
```

---

## Vector Storage in Qdrant

### Collections

**image_embeddings**
- Stores whole-image embeddings from image_embedding tasks
- Point ID: media_store_id
- Vector: 512-d (CLIP ViT-B/32)
- Payload: {job_id, media_store_id, task_type}

**faces**
- Stores face-level embeddings from face_embedding tasks
- Point ID: media_store_id * 1000 + face_index
- Vector: 512-d (Face embedding model)
- Payload: {job_id, media_store_id, face_index, bbox, landmarks, confidence, task_type}

### Distance Metric

Both collections use **Cosine Similarity**:
- Similarity score ranges from -1.0 to 1.0
- 1.0 = identical vectors
- 0.0 = orthogonal vectors
- -1.0 = opposite vectors
- Typical threshold: 0.7-0.8 for similarity search

### Embedding Normalization

All embeddings are L2-normalized (unit length):
- Ensures fair cosine similarity comparison
- Reduces computational overhead
- Standardizes score range to [0, 1]

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
  "stored_in_vector_db": true,
  "collection": "image_embeddings",
  "point_id": 123
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
      "landmarks": {"left_eye": [120, 160], ...}
    }
  ],
  "face_count": 1
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
      "point_id": 123000,
      "stored_in_vector_db": true
    }
  ],
  "face_count": 1,
  "stored_in_vector_db": true
}
```

## Development

### Running Tests

```bash
pytest
```

All 43 tests pass including:
- 27 API endpoint tests
- 16 vector storage tests

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
- **Qdrant**: Vector database for embeddings
- **python-jose**: JWT validation (ES256)
- **NumPy**: Embedding storage
- **Pillow**: Image processing
- **CLIP**: Image and face embedding model

## Testing

### Vector Storage Tests

Comprehensive tests verify that:
- Embeddings are correctly generated by CLIP
- Vectors are properly normalized for cosine similarity
- Payloads match the actual worker code
- Multiple collections (image_embeddings, faces) work correctly
- Face embeddings use correct point ID scheme (media_store_id * 1000 + face_index)
- Error handling works properly for storage failures

Run tests:
```bash
pytest tests/test_vector_storage.py -v
pytest tests/test_image_embedding.py -v
```

## Next Steps

- [ ] Implement broadcasting system (SSE/MQTT) for real-time job updates
- [ ] Add Prometheus metrics
- [ ] Docker support with docker-compose
- [ ] Production deployment guide
- [ ] Support for additional ML models
- [ ] Batch processing for multiple images

## License

[Your License Here]
