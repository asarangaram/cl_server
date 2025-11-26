# ML Inference Integration - Quick Reference

## Project Structure

```
inference/src/
├── inferences/                    # ML inference implementations
│   ├── __init__.py               # Package exports
│   ├── ml_inference.py           # Abstract base class
│   ├── image_embedding.py        # Image embedding inference (224x224 → 512-d)
│   └── face_embedding.py         # Face embedding inference (112x112 → 512-d normalized)
│
└── vector_store/                 # Vector store clients (moved from vector_store/src)
    ├── __init__.py               # Package exports
    ├── store_interface.py        # Abstract base class
    ├── image_store.py            # Qdrant image embedding store
    └── face_store.py             # Qdrant face embedding store
```

## Usage

### ML Inference

```python
from src.inferences import ImageEmbeddingInference, FaceEmbeddingInference
import numpy as np

# Image embedding
image_inference = ImageEmbeddingInference(embedding_dim=512, input_size=(224, 224))
image_buffer = np.random.randn(224, 224, 3).astype(np.float32)
embedding = image_inference.infer(image_buffer, label="image_1")
# Returns: 512-d numpy array

# Face embedding
face_inference = FaceEmbeddingInference(embedding_dim=512, input_size=(112, 112))
face_buffer = np.random.randn(112, 112, 3).astype(np.float32)
face_embedding = face_inference.infer(face_buffer, label="face_0")
# Returns: 512-d normalized numpy array
```

### Vector Store

```python
from src.vector_store import QdrantImageStore, QdrantFaceStore

# Image store
image_store = QdrantImageStore(url="http://localhost:6333")
image_store.add_vector(
    point_id="job-123",
    vec_f32=embedding,
    payload={"job_id": "job-123", "media_store_id": "media-456"}
)

# Face store
face_store = QdrantFaceStore(url="http://localhost:6333")
face_store.add_vector(
    point_id="job-123-0",
    vec_f32=face_embedding,
    payload={
        "job_id": "job-123",
        "face_index": 0,
        "bbox": {"x": 100, "y": 150, "width": 80, "height": 90}
    }
)
```

## Run Demos

```bash
# Image embedding inference demo
python -m src.inferences.image_embedding

# Face embedding inference demo
python -m src.inferences.face_embedding

# Image store demo
python -m src.vector_store.image_store

# Face store demo
python -m src.vector_store.face_store
```

## Key Differences

### Image vs Face Embedding

| Feature | Image Embedding | Face Embedding |
|---------|----------------|----------------|
| Input Size | 224x224 | 112x112 |
| Output | 512-d vector | 512-d **normalized** vector |
| Use Case | Whole image similarity | Face recognition |
| Normalization | No | Yes (L2 norm = 1.0) |

### Image vs Face Store

| Feature | Image Store | Face Store |
|---------|------------|------------|
| Collection | `image_embeddings` | `face_embeddings` |
| Point ID | `job_id` | `job_id-face_index` |
| Metadata | job_id, media_store_id | + face_index, bbox, confidence |
| Extra Methods | - | `search_by_media_store_id()`, `delete_by_job_id()` |

## Integration with Worker

Replace stub functions in `worker.py`:

```python
from src.inferences import ImageEmbeddingInference, FaceEmbeddingInference
from src.vector_store import QdrantImageStore, QdrantFaceStore

# Initialize
image_inference = ImageEmbeddingInference()
face_inference = FaceEmbeddingInference()
image_store = QdrantImageStore()
face_store = QdrantFaceStore()

# In process_image_embedding()
embedding = image_inference.infer(image_buffer, label=job_id)
image_store.add_vector(job_id, embedding, payload={...})

# In process_face_embedding()
for face_idx, face_crop in enumerate(face_crops):
    embedding = face_inference.infer(face_crop, label=f"face_{face_idx}")
    face_store.add_vector(f"{job_id}-{face_idx}", embedding, payload={...})
```

## Notes

- Both inference classes are **stubs** using random embeddings
- Replace with actual models (CLIP, ArcFace, etc.) in production
- Vector store requires Qdrant running: `vector_store_start`
- All classes follow abstract base class patterns for easy swapping
