"""Background worker for processing inference jobs using VectorCore."""

from __future__ import annotations

import asyncio
import logging
import signal
from typing import Optional

import numpy as np
from cl_ml_tools import VectorCore
from PIL import Image
from sqlalchemy.orm import Session

from .config import QDRANT_URL, WORKER_MAX_RETRIES, WORKER_POLL_INTERVAL
from .database import SessionLocal
from .inferences import (
    FaceDetectionInference,
    FaceEmbeddingInference,
    ImageEmbeddingInference,
    QdrantFaceStore,
    QdrantImageStore,
)
from .job_service import JobService
from .media_store_client import MediaStoreClient
from .models import Job
from .queue import Queue



logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

# Shutdown event for graceful termination
shutdown_event = asyncio.Event()


def signal_handler(signum, frame):
    """Handle shutdown signals."""
    logger.info(f"Received signal {signum}, initiating graceful shutdown...")
    shutdown_event.set()


# Register signal handlers
signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)


class Worker:
    """Background worker for processing inference jobs using VectorCore."""

    def __init__(self, worker_id: str = "worker-1"):
        """
        Initialize worker with ML models and vector stores.

        Args:
            worker_id: Unique worker identifier
        """
        self.worker_id = worker_id
        self.media_store_client = MediaStoreClient()

        logger.info("Initializing ML models...")

        # Initialize inference engines
        self.image_inference = ImageEmbeddingInference()
        self.face_detection = FaceDetectionInference()
        self.face_inference = FaceEmbeddingInference()

        # Initialize vector stores
        self.image_store = QdrantImageStore(url=QDRANT_URL, logger=logger)
        self.face_store = QdrantFaceStore(url=QDRANT_URL, logger=logger)


        # Initialize VectorCore for image embeddings
        self.image_vector_core = VectorCore(
            inference_engine=self.image_inference,
            store_interface=self.image_store,
            logger=logger,
            preprocess_cb=self._preprocess_image,
        )

        # Initialize VectorCore for face embeddings
        self.face_vector_core = VectorCore(
            inference_engine=self.face_inference,
            store_interface=self.face_store,
            logger=logger,
            preprocess_cb=self._preprocess_image,
        )

        logger.info("✓ Worker initialized successfully")

    def _preprocess_image(self, data) -> Optional[np.ndarray]:
        """
        Preprocess image data for inference.

        Args:
            data: Image data (PIL Image or numpy array)

        Returns:
            Preprocessed numpy array or None
        """
        try:
            if isinstance(data, np.ndarray):
                return data
            elif isinstance(data, Image.Image):
                return np.array(data.convert("RGB"), dtype=np.uint8)
            else:
                return None
        except Exception as e:
            logger.error(f"Error preprocessing image: {e}")
            return None

    async def run(self):
        """Run the worker loop."""
        logger.info(f"Worker {self.worker_id} starting...")

        try:
            while not shutdown_event.is_set():
                # Get database session
                db = SessionLocal()
                try:
                    # Try to dequeue a job
                    queue = Queue(db)
                    job_id = queue.dequeue(self.worker_id)

                    if job_id:
                        logger.info(f"Processing job {job_id}")
                        await self.process_job(job_id, db)
                    else:
                        # No jobs available, sleep
                        await asyncio.sleep(WORKER_POLL_INTERVAL)

                finally:
                    db.close()

        except Exception as e:
            logger.error(f"Worker error: {e}", exc_info=True)
        finally:
            await self.media_store_client.close()
            logger.info(f"Worker {self.worker_id} stopped")

    async def process_job(self, job_id: str, db: Session):
        """
        Process a single job using VectorCore.

        Args:
            job_id: Job identifier
            db: Database session
        """
        service = JobService(db)

        try:
            # Get job details
            job = db.query(Job).filter_by(job_id=job_id).first()
            if not job:
                logger.error(f"Job {job_id} not found")
                return

            # Update status to processing
            service.update_job_status(job_id, "processing")

            # Fetch image from media_store
            logger.info(f"Fetching image for job {job_id} from media_store")
            image_data = await self.media_store_client.fetch_image(job.media_store_id)

            # Convert to PIL Image
            image = Image.open(image_data)

            # Run inference based on task type
            if job.task_type == "image_embedding":
                result = await self.process_image_embedding(job_id, job.media_store_id, image)
            elif job.task_type == "face_detection":
                result = await self.process_face_detection(job_id, image)
                # Upload face detection results to media_store
                await self.upload_results_with_retry(job.media_store_id, result, db, job_id)
            elif job.task_type == "face_embedding":
                result = await self.process_face_embedding(job_id, job.media_store_id, image)
            else:
                raise ValueError(f"Unknown task type: {job.task_type}")

            # Update job status to completed
            service.update_job_status(job_id, "completed", result=result)


            logger.info(f"Job {job_id} completed successfully")

        except Exception as e:
            logger.error(f"Job {job_id} failed: {e}", exc_info=True)

            # Check retry count
            job = db.query(Job).filter_by(job_id=job_id).first()
            if job and job.retry_count < WORKER_MAX_RETRIES:
                # Increment retry count and re-queue
                job.retry_count += 1
                db.commit()

                # Re-enqueue with same priority
                queue = Queue(db)
                queue.enqueue(job_id, priority=5)  # TODO: Get original priority

                logger.info(f"Job {job_id} re-queued (retry {job.retry_count}/{WORKER_MAX_RETRIES})")
            else:
                # Max retries reached
                service.update_job_status(job_id, "error", error_message=str(e))
                logger.error(f"Job {job_id} failed after {WORKER_MAX_RETRIES} retries")

    async def process_image_embedding(self, job_id: str, media_store_id: str, image: Image.Image) -> dict:
        """
        Process image embedding task using VectorCore.

        Args:
            job_id: Job ID
            media_store_id: Media store ID (used as vector store point ID)
            image: PIL Image

        Returns:
            Result dictionary with embedding info
        """
        logger.info(f"Generating and storing image embedding for job {job_id}")

        # Use VectorCore to generate embedding and store in Qdrant
        # Point ID is the media_store_id (integer)
        success = self.image_vector_core.add_file(
            id=int(media_store_id),
            data=image,
            payload={
                "job_id": job_id,
                "media_store_id": int(media_store_id),
                "task_type": "image_embedding",
            },
            force=True,  # Always update
        )

        if not success:
            raise Exception("Failed to generate or store image embedding")

        return {
            "embedding_dimension": 512,
            "stored_in_vector_db": True,
            "collection": "image_embeddings",
            "point_id": int(media_store_id),
        }

    async def process_face_detection(self, job_id: str, image: Image.Image) -> dict:
        """
        Process face detection task.

        Args:
            job_id: Job ID
            image: PIL Image

        Returns:
            Result dictionary with detected faces
        """
        logger.info(f"Detecting faces for job {job_id}")

        # Convert PIL to numpy
        image_np = np.array(image.convert("RGB"), dtype=np.uint8)

        # Detect faces
        faces = self.face_detection.detect_faces(image_np)

        # Note: Face detection results are returned and will be uploaded to media_store
        return {
            "faces": faces,
            "face_count": len(faces),
        }

    async def process_face_embedding(self, job_id: str, media_store_id: str, image: Image.Image) -> dict:
        """
        Process face embedding task using VectorCore.

        Args:
            job_id: Job ID
            media_store_id: Media store ID (used as base for vector store point IDs)
            image: PIL Image

        Returns:
            Result dictionary with face embeddings info
        """
        logger.info(f"Generating and storing face embeddings for job {job_id}")

        # Convert PIL to numpy
        image_np = np.array(image.convert("RGB"), dtype=np.uint8)

        # Get all faces with embeddings
        faces = self.face_inference.get_all_faces(image_np)

        if not faces:
            return {
                "faces": [],
                "face_count": 0,
                "stored_in_vector_db": False,
            }

        # Store each face embedding in Qdrant using VectorCore
        stored_faces = []
        for face in faces:
            face_idx = face["face_index"]
            # Point ID: media_store_id * 1000 + face_index (ensures uniqueness)
            point_id = int(media_store_id) * 1000 + face_idx

            # Store in vector database
            success = self.face_vector_core.add_file(
                id=point_id,
                data=face["embedding"],  # Already computed
                payload={
                    "job_id": job_id,
                    "media_store_id": int(media_store_id),
                    "face_index": face_idx,
                    "bbox": face["bbox"],
                    "landmarks": face["landmarks"],
                    "confidence": face["confidence"],
                    "task_type": "face_embedding",
                },
                force=True,
            )

            if success:
                stored_faces.append({
                    "face_index": face_idx,
                    "bbox": face["bbox"],
                    "confidence": face["confidence"],
                    "embedding_dimension": face["embedding_dimension"],
                    "point_id": point_id,
                })

        return {
            "faces": stored_faces,
            "face_count": len(stored_faces),
            "stored_in_vector_db": True,
            "collection": "face_embeddings",
        }

    async def upload_results_with_retry(
        self, media_store_id: str, results: dict, db: Session, job_id: str, max_retries: int = 3
    ):
        """
        Upload results to media_store with exponential backoff retry.

        Args:
            media_store_id: Media store ID
            results: Results to upload
            db: Database session
            job_id: Job ID
            max_retries: Maximum number of retries
        """
        for attempt in range(max_retries):
            try:
                # Upload results
                response = await self.media_store_client.post_results(media_store_id, results)
                logger.info(f"Results uploaded successfully for job {job_id}")
                return

            except Exception as e:
                logger.warning(f"Upload attempt {attempt + 1}/{max_retries} failed: {e}")

                if attempt < max_retries - 1:
                    # Exponential backoff
                    delay = min(2**attempt, 60)  # Max 60 seconds
                    await asyncio.sleep(delay)
                else:
                    # Max retries reached
                    logger.error(f"Failed to upload results for job {job_id} after {max_retries} attempts")
                    raise



async def main():
    """Main entry point for worker."""
    worker = Worker()
    await worker.run()


if __name__ == "__main__":
    asyncio.run(main())
