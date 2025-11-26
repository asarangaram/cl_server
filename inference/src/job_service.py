"""Job service for managing inference jobs."""

from __future__ import annotations

import json
import shutil
import time
import uuid
from pathlib import Path
from typing import Optional

from sqlalchemy.orm import Session

from .config import STORAGE_DIR
from .models import Job, MediaStoreSyncStatus, QueueEntry
from .queue import Queue
from .schemas import JobResponse
import logging

class JobService:
    """Service for managing inference jobs."""

    def __init__(self, db: Session):
        """
        Initialize job service.

        Args:
            db: SQLAlchemy database session
        """
        self.db = db
        self.queue = Queue(db)
        self.storage_dir = Path(STORAGE_DIR)

    def create_job(
        self,
        task_type: str,
        media_store_id: str,
        priority: int = 5,
        created_by: Optional[str] = None,
    ) -> JobResponse:
        """
        Create a new inference job.

        Args:
            task_type: Type of inference task
            media_store_id: ID of media in media_store
            priority: Job priority (0-10)
            created_by: User ID from JWT token

        Returns:
            JobResponse with job details

        Raises:
            ValueError: If task_type is invalid or job already exists
        """
        # Validate task type
        valid_tasks = {"image_embedding", "face_detection", "face_embedding"}
        if task_type not in valid_tasks:
            raise ValueError(f"Invalid task_type. Must be one of {valid_tasks}")

        # Check for duplicate
        existing = (
            self.db.query(Job)
            .filter_by(media_store_id=media_store_id, task_type=task_type)
            .filter(Job.status.in_(["pending", "processing"]))
            .first()
        )
        if existing:
            raise ValueError(
                f"Job already exists for media_store_id={media_store_id}, task_type={task_type}"
            )

        # Create job
        job_id = str(uuid.uuid4())
        now = int(time.time() * 1000)

        job = Job(
            job_id=job_id,
            task_type=task_type,
            media_store_id=media_store_id,
            status="pending",
            created_at=now,
            created_by=created_by,
        )

        self.db.add(job)
        self.db.flush()

        # Add to queue
        self.queue.enqueue(job_id, priority)

        # Create sync status
        sync_status = MediaStoreSyncStatus(
            job_id=job_id,
            sync_status="pending",
        )
        self.db.add(sync_status)

        self.db.commit()

        return self._job_to_response(job, priority)

    def get_job(self, job_id: str) -> Optional[JobResponse]:
        """
        Get job by ID.

        Args:
            job_id: Job identifier

        Returns:
            JobResponse or None if not found
        """
        job = self.db.query(Job).filter_by(job_id=job_id).first()
        if job is None:
            return None

        # Get priority from queue if still pending
        priority = 5  # default
        queue_entry = self.db.query(QueueEntry).filter_by(job_id=job_id).first()
        if queue_entry:
            priority = queue_entry.priority

        return self._job_to_response(job, priority)

    def delete_job(self, job_id: str) -> bool:
        """
        Delete job and all associated data.

        Args:
            job_id: Job identifier

        Returns:
            True if deleted, False if not found
        """
        job = self.db.query(Job).filter_by(job_id=job_id).first()
        if job is None:
            return False

        # Remove from queue
        self.queue.remove(job_id)

        # Delete job files
        job_dir = self.storage_dir / job_id
        if job_dir.exists():
            shutil.rmtree(job_dir)

        # Delete job (cascade will delete sync status)
        self.db.delete(job)
        self.db.commit()

        return True

    def update_job_status(
        self,
        job_id: str,
        status: str,
        error_message: Optional[str] = None,
        result: Optional[dict] = None,
    ) -> bool:
        """
        Update job status and result.

        Args:
            job_id: Job identifier
            status: New status
            error_message: Error message if status is 'error'
            result: Result data if status is 'completed'

        Returns:
            True if updated, False if not found
        """
        job = self.db.query(Job).filter_by(job_id=job_id).first()
        if job is None:
            return False

        job.status = status
        now = int(time.time() * 1000)

        if status == "processing" and job.started_at is None:
            job.started_at = now
        elif status in ("completed", "error", "sync_failed"):
            job.completed_at = now

        if error_message:
            job.error_message = error_message

        if result:
            job.result = json.dumps(result)

        self.db.commit()
        return True

    def _job_to_response(self, job: Job, priority: int = 5) -> JobResponse:
        """
        Convert Job model to JobResponse.

        Args:
            job: Job model instance
            priority: Job priority

        Returns:
            JobResponse
        """
        try:
            result = None
            if job.result:
                try:
                    result = json.loads(job.result)
                except json.JSONDecodeError:
                    result = None

            return JobResponse(
                job_id=job.job_id,
                task_type=job.task_type,
                media_store_id=job.media_store_id,
                status=job.status,
                priority=priority,
                created_at=job.created_at,
                started_at=job.started_at,
                completed_at=job.completed_at,
                error_message=job.error_message,
                result=result,
            )
        except Exception as e:
            logging.getLogger(__name__).error(f"Error converting job to response: {e}")
            raise


__all__ = ["JobService"]
