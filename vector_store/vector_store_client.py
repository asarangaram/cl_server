"""Qdrant vector store client for the inference service."""

from __future__ import annotations

import logging
from typing import Any, Optional

from qdrant_client import QdrantClient
from qdrant_client.models import Distance, PointStruct, VectorParams

logger = logging.getLogger(__name__)


class VectorStoreClient:
    """Client for interacting with Qdrant vector store."""

    def __init__(self, host: str = "localhost", port: int = 6333):
        """
        Initialize vector store client.

        Args:
            host: Qdrant server host
            port: Qdrant server port
        """
        self.client = QdrantClient(host=host, port=port)
        self.host = host
        self.port = port

    def ensure_collection(
        self,
        collection_name: str,
        vector_size: int = 512,
        distance: Distance = Distance.COSINE,
    ) -> bool:
        """
        Ensure collection exists, create if not.

        Args:
            collection_name: Name of the collection
            vector_size: Dimension of vectors
            distance: Distance metric (COSINE, EUCLID, DOT)

        Returns:
            True if collection was created, False if already existed
        """
        try:
            # Check if collection exists
            collections = self.client.get_collections().collections
            exists = any(c.name == collection_name for c in collections)

            if exists:
                logger.info(f"Collection '{collection_name}' already exists")
                return False

            # Create collection
            self.client.create_collection(
                collection_name=collection_name,
                vectors_config=VectorParams(size=vector_size, distance=distance),
            )

            logger.info(f"Created collection '{collection_name}' (size={vector_size}, distance={distance})")
            return True

        except Exception as e:
            logger.error(f"Failed to ensure collection '{collection_name}': {e}")
            raise

    def store_image_embedding(
        self,
        job_id: str,
        media_store_id: str,
        embedding: list[float],
        metadata: Optional[dict[str, Any]] = None,
    ) -> str:
        """
        Store image embedding in vector store.

        Args:
            job_id: Job identifier (used as point ID)
            media_store_id: Media store ID
            embedding: 512-d embedding vector
            metadata: Additional metadata

        Returns:
            Point ID (job_id)
        """
        collection_name = "image_embeddings"

        # Ensure collection exists
        self.ensure_collection(collection_name, vector_size=len(embedding))

        # Prepare payload
        payload = {
            "job_id": job_id,
            "media_store_id": media_store_id,
            "task_type": "image_embedding",
            **(metadata or {}),
        }

        # Store vector
        self.client.upsert(
            collection_name=collection_name,
            points=[PointStruct(id=job_id, vector=embedding, payload=payload)],
        )

        logger.info(f"Stored image embedding for job {job_id}")
        return job_id

    def store_face_embedding(
        self,
        job_id: str,
        media_store_id: str,
        face_index: int,
        embedding: list[float],
        bbox: dict[str, float],
        metadata: Optional[dict[str, Any]] = None,
    ) -> str:
        """
        Store face embedding in vector store.

        Args:
            job_id: Job identifier
            media_store_id: Media store ID
            face_index: Index of the face
            embedding: 512-d embedding vector
            bbox: Bounding box coordinates
            metadata: Additional metadata

        Returns:
            Point ID (job_id-face_index)
        """
        collection_name = "face_embeddings"

        # Ensure collection exists
        self.ensure_collection(collection_name, vector_size=len(embedding))

        # Create unique point ID
        point_id = f"{job_id}-{face_index}"

        # Prepare payload
        payload = {
            "job_id": job_id,
            "media_store_id": media_store_id,
            "face_index": face_index,
            "bbox": bbox,
            "task_type": "face_embedding",
            **(metadata or {}),
        }

        # Store vector
        self.client.upsert(
            collection_name=collection_name,
            points=[PointStruct(id=point_id, vector=embedding, payload=payload)],
        )

        logger.info(f"Stored face embedding for job {job_id}, face {face_index}")
        return point_id

    def search_similar_images(
        self,
        query_vector: list[float],
        limit: int = 10,
        score_threshold: Optional[float] = None,
    ) -> list[dict[str, Any]]:
        """
        Search for similar images.

        Args:
            query_vector: Query embedding vector
            limit: Maximum number of results
            score_threshold: Minimum similarity score

        Returns:
            List of search results with scores and metadata
        """
        collection_name = "image_embeddings"

        try:
            results = self.client.search(
                collection_name=collection_name,
                query_vector=query_vector,
                limit=limit,
                score_threshold=score_threshold,
            )

            return [
                {
                    "id": hit.id,
                    "score": hit.score,
                    "payload": hit.payload,
                }
                for hit in results
            ]

        except Exception as e:
            logger.error(f"Search failed: {e}")
            raise

    def search_similar_faces(
        self,
        query_vector: list[float],
        limit: int = 10,
        score_threshold: Optional[float] = None,
    ) -> list[dict[str, Any]]:
        """
        Search for similar faces.

        Args:
            query_vector: Query embedding vector
            limit: Maximum number of results
            score_threshold: Minimum similarity score

        Returns:
            List of search results with scores and metadata
        """
        collection_name = "face_embeddings"

        try:
            results = self.client.search(
                collection_name=collection_name,
                query_vector=query_vector,
                limit=limit,
                score_threshold=score_threshold,
            )

            return [
                {
                    "id": hit.id,
                    "score": hit.score,
                    "payload": hit.payload,
                }
                for hit in results
            ]

        except Exception as e:
            logger.error(f"Search failed: {e}")
            raise

    def delete_by_job_id(self, job_id: str) -> int:
        """
        Delete all vectors associated with a job.

        Args:
            job_id: Job identifier

        Returns:
            Number of points deleted
        """
        deleted_count = 0

        # Delete from image_embeddings
        try:
            self.client.delete(
                collection_name="image_embeddings",
                points_selector=[job_id],
            )
            deleted_count += 1
        except Exception as e:
            logger.warning(f"Failed to delete from image_embeddings: {e}")

        # Delete from face_embeddings (multiple points with job_id prefix)
        try:
            # This requires filtering by payload
            self.client.delete(
                collection_name="face_embeddings",
                points_selector={"must": [{"key": "job_id", "match": {"value": job_id}}]},
            )
            # Note: Can't easily count deleted faces without querying first
        except Exception as e:
            logger.warning(f"Failed to delete from face_embeddings: {e}")

        logger.info(f"Deleted vectors for job {job_id}")
        return deleted_count

    def get_collection_info(self, collection_name: str) -> dict[str, Any]:
        """
        Get collection information.

        Args:
            collection_name: Name of the collection

        Returns:
            Collection info dict
        """
        try:
            info = self.client.get_collection(collection_name=collection_name)
            return {
                "name": collection_name,
                "vectors_count": info.vectors_count,
                "points_count": info.points_count,
                "status": info.status,
            }
        except Exception as e:
            logger.error(f"Failed to get collection info: {e}")
            raise


__all__ = ["VectorStoreClient"]
