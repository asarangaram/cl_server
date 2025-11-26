"""Background worker for processing inference jobs."""

from __future__ import annotations

import asyncio
import json
import logging
import signal
import sys
import time
from typing import Optional

from sqlalchemy.orm import Session

from .config import WORKER_MAX_RETRIES, WORKER_POLL_INTERVAL
from .database import SessionLocal
from .file_storage import FileStorage
from .inference_stubs import detect_faces, generate_face_embeddings, generate_image_embedding
from .job_service import JobService
from .media_store_client import MediaStoreClient
from .models import Job, MediaStoreSyncStatus
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
    """Background worker for processing inference jobs."""

    def __init__(self, worker_id: str = "worker-1"):
        """
        Initialize worker.

        Args:
            worker_id: Unique worker identifier
        """
        self.worker_id = worker_id
        self.media_store_client = MediaStoreClient()
        self.file_storage = FileStorage()

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
        Process a single job.

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
            image = await self.media_store_client.fetch_image(job.media_store_id)

            # Run inference based on task type
            if job.task_type == "image_embedding":
                result = await self.process_image_embedding(job_id, image)
            elif job.task_type == "face_detection":
                result = await self.process_face_detection(job_id, image)
            elif job.task_type == "face_embedding":
                result = await self.process_face_embedding(job_id, image)
            else:
                raise ValueError(f"Unknown task type: {job.task_type}")

            # Upload results to media_store (with retry)
            await self.upload_results_with_retry(job.media_store_id, result, db, job_id)

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

    async def process_image_embedding(self, job_id: str, image) -> dict:
        """Process image embedding task."""
        logger.info(f"Generating image embedding for job {job_id}")

        # Generate embedding
        result = generate_image_embedding(image)

        # Save embedding to file
        embedding_path = self.file_storage.save_embedding(job_id, result["embedding"])

        return {
            "embedding_dimension": result["dimension"],
            "embedding_path": embedding_path,
        }

    async def process_face_detection(self, job_id: str, image) -> dict:
        """Process face detection task."""
        logger.info(f"Detecting faces for job {job_id}")

        # Detect faces
        faces = detect_faces(image)

        # Save face crops
        result_faces = []
        for face in faces:
            crop_path = self.file_storage.save_face_crop(job_id, face["face_index"], face["crop"])

            result_faces.append(
                {
                    "face_index": face["face_index"],
                    "bbox": face["bbox"],
                    "confidence": face["confidence"],
                    "landmarks": face["landmarks"],
                    "crop_path": crop_path,
                }
            )

        return {"faces": result_faces}

    async def process_face_embedding(self, job_id: str, image) -> dict:
        """Process face embedding task."""
        logger.info(f"Generating face embeddings for job {job_id}")

        # Generate face embeddings
        faces = generate_face_embeddings(image)

        # Save face crops and embeddings
        result_faces = []
        for face in faces:
            crop_path = self.file_storage.save_face_crop(job_id, face["face_index"], face["crop"])
            embedding_path = self.file_storage.save_face_embedding(
                job_id, face["face_index"], face["embedding"]
            )

            result_faces.append(
                {
                    "face_index": face["face_index"],
                    "bbox": face["bbox"],
                    "confidence": face["confidence"],
                    "embedding_dimension": face["embedding_dimension"],
                    "embedding_path": embedding_path,
                    "crop_path": crop_path,
                }
            )

        return {"faces": result_faces}

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
        sync_status = db.query(MediaStoreSyncStatus).filter_by(job_id=job_id).first()

        for attempt in range(max_retries):
            try:
                # Update sync status
                if sync_status:
                    sync_status.sync_status = "in_progress"
                    sync_status.sync_attempted_at = int(time.time() * 1000)
                    db.commit()

                # Upload results
                response = await self.media_store_client.post_results(media_store_id, results)

                # Update sync status to completed
                if sync_status:
                    sync_status.sync_status = "completed"
                    sync_status.sync_completed_at = int(time.time() * 1000)
                    db.commit()

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
                    if sync_status:
                        sync_status.sync_status = "failed"
                        sync_status.sync_error = str(e)
                        db.commit()

                    logger.error(f"Failed to upload results for job {job_id} after {max_retries} attempts")
                    raise


async def main():
    """Main entry point for worker."""
    worker = Worker()
    await worker.run()


if __name__ == "__main__":
    asyncio.run(main())
