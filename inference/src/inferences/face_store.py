"""Face embedding store implementation using Qdrant."""

from typing import Optional

import numpy as np
from cl_ml_tools import StoreInterface
from qdrant_client import QdrantClient
from qdrant_client.http.models import HnswConfigDiff, PointStruct
from qdrant_client.models import Distance, VectorParams




class QdrantFaceStore(StoreInterface):
    """
    Manages face vectors in a Qdrant collection.

    This class provides an interface to interact with Qdrant for face embeddings,
    handling collection creation, adding new face embeddings with metadata (bbox, etc.),
    retrieving, deleting, and performing similarity searches for face recognition.
    """

    def __init__(
        self,
        collection_name: str = "face_embeddings",
        url: str = "http://localhost:6333",
        vector_size: int = 512,
        distance: Distance = Distance.COSINE,
        hnsw_m: int = 16,
        hnsw_ef_construct: int = 200,
        max_segment_size: int = 100000,
        logger=None,
    ):
        """
        Initialize the Qdrant face vector store, creating the collection if missing.

        Args:
            collection_name: Name of the Qdrant collection
            url: Qdrant server URL
            vector_size: Dimension of vectors (default 512)
            distance: Distance metric (COSINE, EUCLID, DOT)
            hnsw_m: HNSW index parameter - number of edges per node
            hnsw_ef_construct: HNSW construction parameter
            max_segment_size: Maximum segment size for optimization
            logger: Optional logger instance
        """
        self.collection_name = collection_name
        self.client = QdrantClient(url)
        self.logger = logger

        vector_params = VectorParams(size=vector_size, distance=distance)
        hnsw_params = HnswConfigDiff(m=hnsw_m, ef_construct=hnsw_ef_construct)
        optimizer_params = {"max_segment_size": max_segment_size}

        if not self.client.collection_exists(collection_name=collection_name):
            if self.logger:
                self.logger.debug(f"Creating collection: {collection_name}")
            self.client.create_collection(
                collection_name=collection_name,
                vectors_config=vector_params,
                hnsw_config=hnsw_params,
                optimizers_config=optimizer_params,
            )
        else:
            if self.logger:
                self.logger.debug(f"Collection '{collection_name}' already exists. Reusing it.")
            existing = self.client.get_collection(collection_name=collection_name)
            existing_params = existing.config.params.vectors
            if (
                existing_params.size != vector_params.size
                or existing_params.distance.value != vector_params.distance.value
            ):
                if self.logger:
                    self.logger.error("Collection config differs from expected parameters!")
                    self.logger.error(
                        f"Existing size: {existing_params.size}, distance: {existing_params.distance}"
                    )
                    self.logger.error(
                        f"Expected size: {vector_params.size}, distance: {vector_params.distance}"
                    )
                raise ValueError("Collection config mismatch.")

    def add_vector(self, point_id, vec_f32: np.ndarray, payload: Optional[dict] = None):
        """
        Add or update a single face vector to Qdrant.

        Args:
            point_id: Unique identifier (int or str, typically media_store_id*1000+face_index)
            vec_f32: Vector as numpy array (float32)
            payload: Optional metadata dict (job_id, media_store_id, face_index, bbox, etc.)
        """
        point = PointStruct(
            id=point_id,  # Qdrant accepts both int and str
            vector=vec_f32.tolist() if isinstance(vec_f32, np.ndarray) else vec_f32,
            payload=payload or {},
        )

        self.client.upsert(collection_name=self.collection_name, points=[point])
        if self.logger:
            self.logger.debug(f"Upserted face embedding: {point_id}")

    def get_vector(self, point_id):
        """
        Retrieve a point from Qdrant using the point ID.

        Args:
            point_id: Unique identifier (int or str)

        Returns:
            List of retrieved points
        """
        return self.client.retrieve(collection_name=self.collection_name, ids=[point_id])

    def delete_vector(self, point_id):
        """
        Delete a point based on its ID.

        Args:
            point_id: Unique identifier (int or str)
        """
        self.client.delete(collection_name=self.collection_name, points_selector={"points": [point_id]})
        if self.logger:
            self.logger.debug(f"Deleted face embedding: {point_id}")


    def delete_by_job_id(self, job_id: str):
        """
        Delete all face embeddings associated with a job.

        Args:
            job_id: Job identifier

        Returns:
            Number of points deleted (if available)
        """
        # Delete using filter on job_id payload field
        self.client.delete(
            collection_name=self.collection_name,
            points_selector={"filter": {"must": [{"key": "job_id", "match": {"value": job_id}}]}},
        )
        if self.logger:
            self.logger.debug(f"Deleted all face embeddings for job: {job_id}")

    def search(
        self,
        query_vector,
        limit: int = 5,
        with_payload: bool = True,
        score_threshold: float = 0.85,
    ):
        """
        Search for similar face vectors in the collection.

        Args:
            query_vector: The query embedding (float32 list or numpy array)
            limit: Number of nearest neighbors to return
            with_payload: Whether to return payload (metadata) along with results
            score_threshold: Minimum similarity score

        Returns:
            List of search results with (id, score, payload including bbox)
        """
        if isinstance(query_vector, np.ndarray):
            query_vector = query_vector.tolist()

        results = self.client.search(
            collection_name=self.collection_name,
            query_vector=query_vector,
            limit=limit,
            score_threshold=score_threshold,
            with_payload=with_payload,
        )

        formatted = []
        for r in results:
            point_data = {"id": r.id, "score": r.score}
            if r.payload:
                point_data.update(r.payload)
            formatted.append(point_data)

        if self.logger:
            self.logger.debug(f"Face search returned {len(formatted)} results.")
        return formatted

    def search_by_media_store_id(
        self,
        query_vector,
        media_store_id: str,
        limit: int = 5,
        score_threshold: float = 0.85,
    ):
        """
        Search for similar faces within a specific media item.

        Args:
            query_vector: The query embedding
            media_store_id: Filter results to this media item
            limit: Number of results
            score_threshold: Minimum similarity score

        Returns:
            List of search results filtered by media_store_id
        """
        if isinstance(query_vector, np.ndarray):
            query_vector = query_vector.tolist()

        results = self.client.search(
            collection_name=self.collection_name,
            query_vector=query_vector,
            limit=limit,
            score_threshold=score_threshold,
            query_filter={"must": [{"key": "media_store_id", "match": {"value": media_store_id}}]},
            with_payload=True,
        )

        formatted = []
        for r in results:
            point_data = {"id": r.id, "score": r.score}
            if r.payload:
                point_data.update(r.payload)
            formatted.append(point_data)

        if self.logger:
            self.logger.debug(f"Face search (filtered) returned {len(formatted)} results.")
        return formatted



__all__ = ["QdrantFaceStore"]


if __name__ == "__main__":
    """Demo usage of QdrantFaceStore."""
    import logging

    # Setup logging
    logging.basicConfig(level=logging.DEBUG)
    logger = logging.getLogger(__name__)

    print("\n" + "=" * 60)
    print("FACE STORE DEMO")
    print("=" * 60)

    # Initialize face store
    store = QdrantFaceStore(
        collection_name="face_embeddings",
        url="http://localhost:6333",
        vector_size=512,
        logger=logger,
    )

    # Add face embeddings for multiple jobs
    print("\n1. Adding face embeddings...")
    for job_idx in range(2):
        job_id = f"job-face-{job_idx}"
        media_id = f"media-{job_idx}"

        # Each job has 2-3 faces
        num_faces = 2 + job_idx
        for face_idx in range(num_faces):
            point_id = f"{job_id}-{face_idx}"
            embedding = np.random.randn(512).astype(np.float32)
            payload = {
                "job_id": job_id,
                "media_store_id": media_id,
                "face_index": face_idx,
                "bbox": {
                    "x": 100.0 + face_idx * 50,
                    "y": 150.0,
                    "width": 80.0,
                    "height": 90.0,
                },
                "confidence": 0.95 + face_idx * 0.01,
                "task_type": "face_embedding",
            }

            store.add_vector(point_id=point_id, vec_f32=embedding, payload=payload)
            print(f"   Added: {point_id} (media: {media_id})")

    # Retrieve a vector
    print("\n2. Retrieving face vector...")
    result = store.get_vector("job-face-0-0")
    if result:
        print(f"   Retrieved: {result[0].id}")
        print(f"   BBox: {result[0].payload.get('bbox')}")

    # Search for similar faces (global)
    print("\n3. Searching for similar faces (global)...")
    query_vector = np.random.randn(512).astype(np.float32)
    results = store.search(query_vector=query_vector, limit=5, score_threshold=0.0)

    print(f"   Found {len(results)} similar faces:")
    for r in results:
        print(
            f"      - ID: {r['id']}, Score: {r['score']:.4f}, "
            f"Media: {r.get('media_store_id')}, Face: {r.get('face_index')}"
        )

    # Search within specific media
    print("\n4. Searching for similar faces (within media-0)...")
    results = store.search_by_media_store_id(
        query_vector=query_vector, media_store_id="media-0", limit=5, score_threshold=0.0
    )

    print(f"   Found {len(results)} similar faces in media-0:")
    for r in results:
        print(f"      - ID: {r['id']}, Score: {r['score']:.4f}, Face: {r.get('face_index')}")

    # Delete all faces for a job
    print("\n5. Deleting all faces for job-face-0...")
    store.delete_by_job_id("job-face-0")
    print("   Deleted all faces for: job-face-0")

    # Verify deletion
    print("\n6. Verifying deletion...")
    results = store.search_by_media_store_id(
        query_vector=query_vector, media_store_id="media-0", limit=5, score_threshold=0.0
    )
    print(f"   Remaining faces in media-0: {len(results)}")

    print("\n" + "=" * 60)
    print("✅ Demo completed!")
    print("=" * 60)
