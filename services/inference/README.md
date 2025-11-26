# Inference Microservice

An asynchronous inference service for processing images with two main workflows: **Image Embedding** and **Face Detection**. The service uses a job-based architecture with priority queuing and vector storage for efficient similarity searches.

## Workflows

### 1. Image Embedding

**What it does**: Generates a 512-dimensional vector embedding for an entire image using CLIP ViT-B/32 model. The embedding captures the semantic content of the image and can be used for similarity search.

**Why use it**:
- Find visually similar images in your database
- Perform reverse image search
- Cluster images by visual content
- Semantic image search

**Expected Input**:
- An image file (uploaded to media_store first)
- Media store ID of the image

**Expected Output**:
- 512-dimensional vector embedding
- Embedding stored in Qdrant vector database
- Collection name: `image_embeddings`
- Point ID: the media_store_id

**Step-by-Step Flow**:
1. Upload image to media_store → get media_store_id
2. Create inference job with task_type=`image_embedding`
3. Inference service fetches image from media_store
4. CLIP model generates 512-d normalized embedding
5. Embedding stored in Qdrant with media_store_id as point ID
6. Job completes with result containing point_id and collection name

### 2. Face Detection

**What it does**: Detects all faces in an image using RetinaFace model and returns bounding boxes, facial landmarks, and confidence scores for each detected face.

**Why use it**:
- Extract face regions from images
- Get facial landmark locations for face alignment
- Count faces in an image
- Prepare images for face recognition workflows

**Expected Input**:
- An image file (uploaded to media_store first)
- Media store ID of the image

**Expected Output**:
- List of detected faces with:
  - Bounding box coordinates (x, y, width, height)
  - 5 facial landmarks (eyes, nose, mouth corners)
  - Confidence score for detection
  - Face index (position in image)
- Face count

**Step-by-Step Flow**:
1. Upload image to media_store → get media_store_id
2. Create inference job with task_type=`face_detection`
3. Inference service fetches image from media_store
4. RetinaFace model detects all faces
5. For each face, extract bounding box and landmarks
6. Results sent to media_store (stub endpoint accepts but doesn't store)
7. Job completes with result containing face list and count

## Setup and Installation

### Requirements
- Python 3.9+
- Inference service running (port 8001)
- Media store service running (port 8000)
- MQTT broker running (port 1883) for event notifications
- 1+ GB GPU memory recommended (CPU falls back but slower)

### Installation

1. **Create virtual environment**:
```bash
python3 -m venv services/inference/venv
source services/inference/venv/bin/activate
```

2. **Install dependencies**:
```bash
pip install -r services/inference/pyproject.toml
```

3. **Configure services** (if needed):
- Set `AUTH_DISABLED=true` environment variable for test mode (no JWT tokens required)
- MQTT broker should be accessible at `localhost:1883`

4. **Start the service**:
```bash
python services/inference/main.py
```

Service will be available at `http://localhost:8001`

## API Reference

### Create Inference Job

**Endpoint**: `POST /job/{task_type}`

**Parameters**:
- `task_type` (path): One of `image_embedding` or `face_detection`

**Request Body**:
```json
{
  "media_store_id": 12345,
  "priority": 7
}
```

**Response** (HTTP 201):
```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "task_type": "image_embedding",
  "media_store_id": 12345,
  "status": "pending",
  "priority": 7,
  "created_at": 1732000000000,
  "started_at": null,
  "completed_at": null,
  "error_message": null,
  "result": null
}
```

**Error Responses**:
- `400`: Invalid task_type or priority out of range (0-10)
- `409`: Job already exists for this media_store_id + task_type
- `422`: Validation error (missing fields, invalid types)

### Get Job Status

**Endpoint**: `GET /job/{job_id}`

**Parameters**:
- `job_id` (path): UUID of the job

**Response** (HTTP 200):
```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "task_type": "image_embedding",
  "media_store_id": 12345,
  "status": "completed",
  "priority": 7,
  "created_at": 1732000000000,
  "started_at": 1732000005000,
  "completed_at": 1732000015000,
  "error_message": null,
  "result": {
    "embedding_dimension": 512,
    "stored_in_vector_db": true,
    "collection": "image_embeddings",
    "point_id": 12345
  }
}
```

### Job Status Values

- `pending`: Job created, waiting in queue
- `processing`: Job currently being processed by worker
- `completed`: Job successfully finished
- `error`: Job failed with error_message populated
- `sync_failed`: Results failed to sync to media_store

### Result Formats by Task Type

**Image Embedding Result**:
```json
{
  "embedding_dimension": 512,
  "stored_in_vector_db": true,
  "collection": "image_embeddings",
  "point_id": 12345
}
```

**Face Detection Result**:
```json
{
  "faces": [
    {
      "face_index": 0,
      "bbox": {
        "x": 100.5,
        "y": 200.3,
        "width": 150.0,
        "height": 200.0
      },
      "landmarks": [
        [120.0, 220.0],
        [140.0, 220.0],
        [130.0, 240.0],
        [110.0, 250.0],
        [150.0, 250.0]
      ],
      "confidence": 0.95
    }
  ],
  "face_count": 1
}
```

## Client Usage Guide

### Using the Python CLI Clients

The recommended way to use the inference service is via the provided Python CLI clients in `demos/inferences/`.

#### Image Embedding Example
```bash
cd demos/inferences
source venv/bin/activate
python image_embedding_client.py /path/to/image.jpg --media-store localhost:8000
```

#### Face Detection Example
```bash
cd demos/inferences
source venv/bin/activate
python face_detection_client.py /path/to/image.jpg --media-store localhost:8000
```

#### CLI Options
```
--media-store MEDIA_STORE_URL    Media store service URL (required)
--inference INFERENCE_URL        Inference service URL (default: localhost:8001)
--timeout SECONDS                Job timeout in seconds (default: 300)
```

### Understanding Results

After a successful job, the CLI will output JSON results:

**Image Embedding Results**:
- `point_id`: Use this to query the Qdrant vector database for similar images
- `collection`: Name of the Qdrant collection storing this embedding

**Face Detection Results**:
- `faces`: Array of detected faces with bounding boxes and landmarks
- `face_count`: Total number of faces detected
- Use bounding boxes to crop and extract face images

## Workflow Examples

### Complete Image Embedding Workflow
```bash
# 1. Upload image to media_store
curl -X POST http://localhost:8000/entity/ \
  -F "is_collection=false" \
  -F "label=my_image" \
  -F "file=@image.jpg"
# Response: { "id": 123, ... }

# 2. Create inference job
curl -X POST http://localhost:8001/job/image_embedding \
  -H "Content-Type: application/json" \
  -d '{"media_store_id": 123, "priority": 5}'
# Response: { "job_id": "550e8400...", "status": "pending", ... }

# 3. Wait for completion (via MQTT or polling)
# MQTT topic: inference/job/550e8400-e29b-41d4-a716-446655440000/completed

# 4. Get results
curl http://localhost:8001/job/550e8400-e29b-41d4-a716-446655440000
# Response: { "status": "completed", "result": { "point_id": 123, ... } }
```

### Complete Face Detection Workflow
```bash
# 1. Upload image to media_store
curl -X POST http://localhost:8000/entity/ \
  -F "is_collection=false" \
  -F "label=faces_image" \
  -F "file=@people.jpg"
# Response: { "id": 456, ... }

# 2. Create inference job
curl -X POST http://localhost:8001/job/face_detection \
  -H "Content-Type: application/json" \
  -d '{"media_store_id": 456, "priority": 8}'
# Response: { "job_id": "abc123...", "status": "pending", ... }

# 3. Wait for completion
# MQTT topic: inference/job/abc123-.../completed

# 4. Get results
curl http://localhost:8001/job/abc123-...
# Response: { "status": "completed", "result": { "faces": [...], "face_count": 2 } }
```

## Architecture Details

### Job Queue
- Priority-based queue (higher priority processed first)
- SQLite-backed for persistence
- Multi-worker support with row-level locking
- Automatic retry on failure (up to 3 retries)

### Models
- **Image Embedding**: OpenAI CLIP ViT-B/32 (512-dimensional output)
- **Face Detection**: RetinaFace from InsightFace library

### Vector Storage
- Qdrant vector database for storing and searching embeddings
- Collections: `image_embeddings`, `face_embeddings`
- Fast similarity search with configurable similarity threshold

### Event Notification
- MQTT-based job completion events
- Topic pattern: `inference/job/{job_id}/completed`
- Enables real-time notification of job completion

## Troubleshooting

**Job stuck in "pending" state**:
- Check if inference service worker is running
- Check worker logs for errors
- Verify media_store service is accessible

**"Cannot reach media_store" error**:
- Ensure media_store service is running on port 8000
- Check network connectivity between services

**MQTT events not received**:
- Verify MQTT broker is running on port 1883
- Check MQTT subscription in service logs
- Try polling `GET /job/{job_id}` as fallback

**Out of GPU memory**:
- Service falls back to CPU automatically
- Processing will be slower but still works
- Consider reducing batch size if available

## Performance Notes

- Image embedding: ~100-200ms per image (with GPU)
- Face detection: ~50-100ms per image (with GPU)
- Processing times on CPU are 5-10x slower
- Queue processing is parallel - multiple jobs can run simultaneously

## Notes for Developers

- Face embedding workflow is not yet implemented
- All results are final - there is no incremental processing
- Authentication can be disabled in test mode via `TEST_MODE=true` environment variable
- MQTT broker is required for event notifications; set appropriate MQTT URL if using non-default broker
