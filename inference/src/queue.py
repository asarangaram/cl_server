"""Priority-based persistent queue implementation using SQLite."""

from __future__ import annotations

import time
from typing import Optional

from sqlalchemy.orm import Session

from .models import QueueEntry


class Queue:
    """SQLite-backed persistent queue with priority support."""

    def __init__(self, db: Session):
        """
        Initialize queue.

        Args:
            db: SQLAlchemy database session
        """
        self.db = db

    def enqueue(self, job_id: str, priority: int = 5) -> bool:
        """
        Add job to queue with priority.

        Args:
            job_id: Unique job identifier
            priority: Priority level (0-10, default 5). Higher = more urgent

        Returns:
            True if enqueued, False if already exists
        """
        # Check if already in queue
        existing = self.db.query(QueueEntry).filter_by(job_id=job_id).first()
        if existing:
            return False

        # Validate priority
        if not 0 <= priority <= 10:
            raise ValueError(f"Priority must be between 0 and 10, got {priority}")

        # Create queue entry
        entry = QueueEntry(
            job_id=job_id,
            priority=priority,
            enqueued_at=int(time.time() * 1000),  # Unix timestamp in ms
        )

        self.db.add(entry)
        self.db.commit()
        return True

    def dequeue(self, worker_id: str) -> Optional[str]:
        """
        Get next job from queue (priority-based FIFO).

        Jobs are ordered by:
        1. Priority (descending) - higher priority first
        2. Enqueued time (ascending) - FIFO within same priority

        Args:
            worker_id: Identifier of the worker dequeuing

        Returns:
            job_id or None if queue is empty
        """
        # Find next pending job with highest priority
        entry = (
            self.db.query(QueueEntry)
            .filter(QueueEntry.dequeued_at.is_(None))
            .order_by(QueueEntry.priority.desc(), QueueEntry.enqueued_at.asc())
            .with_for_update()  # Row-level lock for multi-worker safety
            .first()
        )

        if entry is None:
            return None

        # Mark as dequeued
        entry.dequeued_at = int(time.time() * 1000)
        entry.worker_id = worker_id
        self.db.commit()

        return entry.job_id

    def remove(self, job_id: str) -> bool:
        """
        Remove job from queue.

        Args:
            job_id: Job identifier to remove

        Returns:
            True if removed, False if not found
        """
        entry = self.db.query(QueueEntry).filter_by(job_id=job_id).first()
        if entry is None:
            return False

        self.db.delete(entry)
        self.db.commit()
        return True

    def peek(self) -> Optional[tuple[str, int]]:
        """
        View next job without dequeuing.

        Returns:
            Tuple of (job_id, priority) or None if queue is empty
        """
        entry = (
            self.db.query(QueueEntry)
            .filter(QueueEntry.dequeued_at.is_(None))
            .order_by(QueueEntry.priority.desc(), QueueEntry.enqueued_at.asc())
            .first()
        )

        if entry is None:
            return None

        return (entry.job_id, entry.priority)

    def size(self) -> int:
        """
        Get number of pending jobs in queue.

        Returns:
            Count of pending jobs
        """
        return self.db.query(QueueEntry).filter(QueueEntry.dequeued_at.is_(None)).count()

    def get_all_pending(self) -> list[tuple[str, int, int]]:
        """
        Get all pending jobs in queue order.

        Returns:
            List of tuples (job_id, priority, enqueued_at)
        """
        entries = (
            self.db.query(QueueEntry)
            .filter(QueueEntry.dequeued_at.is_(None))
            .order_by(QueueEntry.priority.desc(), QueueEntry.enqueued_at.asc())
            .all()
        )

        return [(e.job_id, e.priority, e.enqueued_at) for e in entries]


__all__ = ["Queue"]
