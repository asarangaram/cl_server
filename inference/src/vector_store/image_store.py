"""Image embedding store implementation using Qdrant."""

from typing import Optional

import numpy as np
from cl_ml_tools import StoreInterface
from qdrant_client import QdrantClient
from qdrant_client.http.models import HnswConfigDiff, PointStruct
from qdrant_client.models import Distance, VectorParams




class QdrantImageStore(StoreInterface):
    """
    Manages image vectors in a Qdrant collection.

    This class provides an interface to interact with Qdrant, handling
    collection creation, adding new image embeddings, retrieving, deleting,
    and performing similarity searches. It ensures that the Qdrant collection
    is properly configured for efficient vector storage and retrieval.
    """

    def __init__(
        self,
        collection_name: str = "image_embeddings",
        url: str = "http://localhost:6333",
        vector_size: int = 512,
        distance: Distance = Distance.COSINE,
        hnsw_m: int = 16,
        hnsw_ef_construct: int = 200,
        max_segment_size: int = 100000,
        logger=None,
    ):
        """
        Initialize the Qdrant image vector store, creating the collection if missing.

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

    def add_vector(self, point_id: str, vec_f32: np.ndarray, payload: Optional[dict] = None):
        """
        Add or update a single image vector to Qdrant.

        Args:
            point_id: Unique identifier (typically job_id)
            vec_f32: Vector as numpy array (float32)
            payload: Optional metadata dict (job_id, media_store_id, etc.)
        """
        point = PointStruct(
            id=point_id,
            vector=vec_f32.tolist() if isinstance(vec_f32, np.ndarray) else vec_f32,
            payload=payload or {},
        )

        self.client.upsert(collection_name=self.collection_name, points=[point])
        if self.logger:
            self.logger.debug(f"Upserted image embedding: {point_id}")

    def get_vector(self, point_id: str):
        """
        Retrieve a point from Qdrant using the point ID.

        Args:
            point_id: Unique identifier

        Returns:
            List of retrieved points
        """
        return self.client.retrieve(collection_name=self.collection_name, ids=[point_id])

    def delete_vector(self, point_id: str):
        """
        Delete a point based on its ID.

        Args:
            point_id: Unique identifier
        """
        self.client.delete(collection_name=self.collection_name, points_selector={"points": [point_id]})
        if self.logger:
            self.logger.debug(f"Deleted image embedding: {point_id}")

    def search(
        self,
        query_vector,
        limit: int = 5,
        with_payload: bool = True,
        score_threshold: float = 0.85,
    ):
        """
        Search for similar vectors in the collection.

        Args:
            query_vector: The query embedding (float32 list or numpy array)
            limit: Number of nearest neighbors to return
            with_payload: Whether to return payload (metadata) along with results
            score_threshold: Minimum similarity score

        Returns:
            List of search results with (id, score, payload)
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
            self.logger.debug(f"Image search returned {len(formatted)} results.")
        return formatted



__all__ = ["QdrantImageStore"]


if __name__ == "__main__":
    """Demo usage of QdrantImageStore."""
    import logging

    # Setup logging
    logging.basicConfig(level=logging.DEBUG)
    logger = logging.getLogger(__name__)

    print("\n" + "=" * 60)
    print("IMAGE STORE DEMO")
    print("=" * 60)

    # Initialize image store
    store = QdrantImageStore(
        collection_name="image_embeddings",
        url="http://localhost:6333",
        vector_size=512,
        logger=logger,
    )

    # Add some image embeddings
    print("\n1. Adding image embeddings...")
    for i in range(3):
        job_id = f"job-img-{i}"
        embedding = np.random.randn(512).astype(np.float32)
        payload = {
            "job_id": job_id,
            "media_store_id": f"media-{i}",
            "task_type": "image_embedding",
            "created_at": 1700000000000 + i * 1000,
        }

        store.add_vector(point_id=job_id, vec_f32=embedding, payload=payload)
        print(f"   Added: {job_id}")

    # Retrieve a vector
    print("\n2. Retrieving vector...")
    result = store.get_vector("job-img-0")
    if result:
        print(f"   Retrieved: {result[0].id}")
        print(f"   Payload: {result[0].payload}")

    # Search for similar images
    print("\n3. Searching for similar images...")
    query_vector = np.random.randn(512).astype(np.float32)
    results = store.search(query_vector=query_vector, limit=3, score_threshold=0.0)

    print(f"   Found {len(results)} similar images:")
    for r in results:
        print(f"      - ID: {r['id']}, Score: {r['score']:.4f}, Media: {r.get('media_store_id')}")

    # Delete a vector
    print("\n4. Deleting vector...")
    store.delete_vector("job-img-0")
    print("   Deleted: job-img-0")

    print("\n" + "=" * 60)
    print("✅ Demo completed!")
    print("=" * 60)
