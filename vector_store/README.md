# Qdrant Vector Store Service

A Qdrant-based vector database for storing embeddings and metadata from the AI Inference Microservice.

## Overview

This service provides a persistent vector store using Qdrant, running in a Docker container with data stored in `../data/vector_store/qdrant`.

## Prerequisites

- Docker and Docker Compose installed
- At least 2GB of free disk space for vector storage

## Quick Start

### 1. Start Qdrant Container

```bash
cd vector_store
./start.sh
```

This will:
- Pull the latest Qdrant image (if not already present)
- Create persistent storage at `../data/vector_store/qdrant`
- Start Qdrant on ports 6333 (REST) and 6334 (gRPC)
- Run the container in the background

### 2. Stop Qdrant Container

```bash
./stop.sh
```

### 3. Verify Qdrant is Running


```bash
# Check container status
docker-compose ps

# Check health
curl http://localhost:6333/health

# View logs
docker-compose logs -f qdrant
```

Expected health response:
```json
{
  "title": "qdrant - vector search engine",
  "version": "x.x.x"
}
```

### 3. Access Qdrant Dashboard

Open in browser: `http://localhost:6333/dashboard`

## Container Management

### Start Container
```bash
./start.sh
# Or manually:
docker-compose up -d
```

### Stop Container
```bash
./stop.sh
# Or manually:
docker-compose stop
```

### Restart Container
```bash
docker-compose restart
```

### Stop and Remove Container
```bash
docker-compose down
```

**Note**: Data persists in `../data/vector_store/qdrant` even after removing the container.

### View Logs
```bash
# Follow logs
docker-compose logs -f qdrant

# View last 100 lines
docker-compose logs --tail=100 qdrant
```

### Remove All Data (Caution!)
```bash
# Stop container first
docker-compose down

# Remove persistent data
rm -rf ../data/vector_store/qdrant

# Restart with fresh data
docker-compose up -d
```

## Ports

- **6333**: REST API endpoint
- **6334**: gRPC API endpoint

## Persistent Storage

Data is stored in: `../data/vector_store/qdrant`

This directory contains:
- Collection metadata
- Vector indexes
- Payloads (metadata)
- Snapshots

## API Endpoints

### Health Check
```bash
curl http://localhost:6333/health
```

### List Collections
```bash
curl http://localhost:6333/collections
```

### Get Collection Info
```bash
curl http://localhost:6333/collections/{collection_name}
```

## Python Client Usage

### Installation

```bash
pip install qdrant-client
```

### Basic Example

```python
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams

# Connect to Qdrant
client = QdrantClient(host="localhost", port=6333)

# Create collection
client.create_collection(
    collection_name="image_embeddings",
    vectors_config=VectorParams(size=512, distance=Distance.COSINE),
)

# Insert vectors
client.upsert(
    collection_name="image_embeddings",
    points=[
        {
            "id": 1,
            "vector": [0.1] * 512,  # 512-dimensional vector
            "payload": {
                "job_id": "uuid",
                "media_store_id": "media123",
                "task_type": "image_embedding"
            }
        }
    ]
)

# Search
results = client.search(
    collection_name="image_embeddings",
    query_vector=[0.1] * 512,
    limit=10
)
```

## Integration with Inference Service

The inference service will use this vector store to:

1. **Store Image Embeddings**: 512-d vectors from image embedding tasks
2. **Store Face Embeddings**: 512-d vectors from face embedding tasks
3. **Metadata Storage**: Job IDs, media store IDs, timestamps, etc.
4. **Similarity Search**: Find similar images or faces

### Collections

**`image_embeddings`**:
- Vector size: 512
- Distance metric: Cosine
- Payload: job_id, media_store_id, created_at

**`face_embeddings`**:
- Vector size: 512
- Distance metric: Cosine
- Payload: job_id, media_store_id, face_index, bbox, created_at

## Configuration

Edit `docker-compose.yml` to customize:

```yaml
environment:
  - QDRANT__SERVICE__GRPC_PORT=6334
  - QDRANT__SERVICE__HTTP_PORT=6333
  # Add more config as needed
```

See [Qdrant Configuration](https://qdrant.tech/documentation/guides/configuration/) for all options.

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose logs qdrant

# Check if ports are in use
lsof -i :6333
lsof -i :6334

# Remove and recreate
docker-compose down
docker-compose up -d
```

### Permission Issues

```bash
# Ensure data directory is writable
chmod -R 755 ../data/vector_store/qdrant
```

### Out of Memory

Qdrant requires at least 1GB RAM. Check Docker resource limits:
```bash
docker stats qdrant-vector-store
```

## Backup and Restore

### Create Snapshot

```bash
curl -X POST http://localhost:6333/collections/{collection_name}/snapshots
```

### List Snapshots

```bash
curl http://localhost:6333/collections/{collection_name}/snapshots
```

### Download Snapshot

```bash
curl http://localhost:6333/collections/{collection_name}/snapshots/{snapshot_name} \
  -o snapshot.tar
```

### Restore from Snapshot

```bash
curl -X PUT http://localhost:6333/collections/{collection_name}/snapshots/upload \
  -H 'Content-Type: multipart/form-data' \
  -F 'snapshot=@snapshot.tar'
```

## Performance Tuning

### Indexing Parameters

Adjust in collection creation:
```python
client.create_collection(
    collection_name="embeddings",
    vectors_config=VectorParams(
        size=512,
        distance=Distance.COSINE,
    ),
    hnsw_config={
        "m": 16,  # Number of edges per node
        "ef_construct": 100,  # Construction time/accuracy tradeoff
    }
)
```

### Search Parameters

```python
results = client.search(
    collection_name="embeddings",
    query_vector=vector,
    limit=10,
    search_params={"hnsw_ef": 128}  # Search time/accuracy tradeoff
)
```

## Resources

- [Qdrant Documentation](https://qdrant.tech/documentation/)
- [Python Client Docs](https://github.com/qdrant/qdrant-client)
- [REST API Reference](https://qdrant.tech/documentation/interfaces/)

## License

Qdrant is licensed under Apache License 2.0
