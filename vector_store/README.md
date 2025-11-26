# Qdrant Vector Store

A Qdrant-based vector database for storing embeddings and metadata from the AI Inference Microservice.

## Project Structure

```
vector_store/
├── src/                          # Client interface implementations
│   ├── __init__.py              # Package exports
│   ├── store_interface.py       # Abstract base class
│   ├── image_store.py           # Image embedding store
│   └── face_store.py            # Face embedding store
├── qdrant_docker/               # Docker configuration
│   ├── docker-compose.yml       # Qdrant container setup
│   └── bin/                     # Executable scripts
│       ├── vector_store_start   # Start Qdrant
│       └── vector_store_stop    # Stop Qdrant
├── requirements.txt             # Python dependencies
├── setup_path.sh                # Add scripts to PATH
└── README.md                    # This file
```

## Quick Start

### 1. Add Scripts to PATH (Optional)

```bash
# Add to your ~/.bashrc or ~/.zshrc
source /path/to/vector_store/setup_path.sh

# Or run directly
export PATH="$PATH:/Users/anandasarangaram/Work/github/cl_server/vector_store/qdrant_docker/bin"
```

### 2. Start Qdrant

```bash
# From anywhere if PATH is set
vector_store_start

# Or with full path
./qdrant_docker/bin/vector_store_start
```

### 3. Stop Qdrant

```bash
# From anywhere if PATH is set
vector_store_stop

# Or with full path
./qdrant_docker/bin/vector_store_stop
```

### 4. Install Python Dependencies

```bash
pip install -r requirements.txt
```

## Usage

### Image Store

```python
from src.image_store import QdrantImageStore
import numpy as np

# Initialize
store = QdrantImageStore(url="http://localhost:6333")

# Add embedding
embedding = np.random.randn(512).astype(np.float32)
store.add_vector(
    point_id="job-123",
    vec_f32=embedding,
    payload={"job_id": "job-123", "media_store_id": "media-456"}
)

# Search
results = store.search(embedding, limit=10, score_threshold=0.85)
```

**Run Demo:**
```bash
python -m src.image_store
```

### Face Store

```python
from src.face_store import QdrantFaceStore

# Initialize
store = QdrantFaceStore(url="http://localhost:6333")

# Add face embedding
store.add_vector(
    point_id="job-123-0",
    vec_f32=embedding,
    payload={
        "job_id": "job-123",
        "media_store_id": "media-456",
        "face_index": 0,
        "bbox": {"x": 100, "y": 150, "width": 80, "height": 90}
    }
)

# Search within specific media
results = store.search_by_media_store_id(
    query_vector=embedding,
    media_store_id="media-456",
    limit=10
)

# Delete all faces for a job
store.delete_by_job_id("job-123")
```

**Run Demo:**
```bash
python -m src.face_store
```

## Qdrant Container

### Ports
- **6333**: REST API
- **6334**: gRPC API

### Dashboard
http://localhost:6333/dashboard

### Persistent Storage
`../data/vector_store/qdrant`

### Management Commands

```bash
# Start
vector_store_start

# Stop
vector_store_stop

# Remove container (keeps data)
cd qdrant_docker && docker-compose down

# View logs
cd qdrant_docker && docker-compose logs -f qdrant

# Check status
cd qdrant_docker && docker-compose ps
```

## Store Interface

All stores implement the `StoreInterface` abstract base class:

```python
class StoreInterface(ABC):
    @abstractmethod
    def add_vector(self, id: int, vector: np.ndarray, payload: Optional[Dict] = None):
        """Add a vector to the store."""
        pass

    @abstractmethod
    def get_vector(self, id: int) -> Optional[List[Dict]]:
        """Retrieve a vector by ID."""
        pass

    @abstractmethod
    def delete_vector(self, id: int):
        """Delete a vector by ID."""
        pass

    @abstractmethod
    def search(self, query_vector: np.ndarray, limit: int = 5) -> List[Dict]:
        """Search for similar vectors."""
        pass
```

## Features

### Image Store (`QdrantImageStore`)
- Store 512-d image embeddings
- COSINE distance metric
- Configurable HNSW parameters
- Auto-creates collection with validation

### Face Store (`QdrantFaceStore`)
- Store 512-d face embeddings with bounding boxes
- Search globally or filter by media_store_id
- Delete all faces for a job
- Face-specific metadata (bbox, confidence, face_index)

## Configuration

Both stores support customization:

```python
store = QdrantImageStore(
    collection_name="custom_images",
    url="http://localhost:6333",
    vector_size=512,
    distance=Distance.COSINE,
    hnsw_m=16,                    # HNSW edges per node
    hnsw_ef_construct=200,        # Construction accuracy
    max_segment_size=100000,      # Optimization parameter
    logger=my_logger
)
```

## Integration with Inference Service

The vector store is designed to work with the AI Inference Microservice:

1. **After Image Embedding**: Store in `image_embeddings` collection
2. **After Face Embedding**: Store in `face_embeddings` collection with bbox metadata
3. **Similarity Search**: Find similar images or faces
4. **Cleanup**: Delete vectors when jobs are removed

## Resources

- [Qdrant Documentation](https://qdrant.tech/documentation/)
- [Python Client](https://github.com/qdrant/qdrant-client)
- [REST API Reference](https://qdrant.tech/documentation/interfaces/)

## License

Apache License 2.0
