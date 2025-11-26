"""SQLAlchemy models for the inference service."""

from __future__ import annotations

import time
from typing import Optional

from sqlalchemy import BigInteger, ForeignKey, Index, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from .database import Base


class Job(Base):
    """Job model storing metadata, status, and results."""

    __tablename__ = "jobs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    job_id: Mapped[str] = mapped_column(String, unique=True, nullable=False, index=True)
    task_type: Mapped[str] = mapped_column(String, nullable=False)
    media_store_id: Mapped[str] = mapped_column(String, nullable=False)
    status: Mapped[str] = mapped_column(String, nullable=False, index=True)
    created_at: Mapped[int] = mapped_column(BigInteger, nullable=False, index=True)
    started_at: Mapped[Optional[int]] = mapped_column(BigInteger, nullable=True)
    completed_at: Mapped[Optional[int]] = mapped_column(BigInteger, nullable=True)
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    retry_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    max_retries: Mapped[int] = mapped_column(Integer, default=3, nullable=False)
    result: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # JSON string
    created_by: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)

    def __repr__(self) -> str:
        return f"<Job(job_id={self.job_id}, task_type={self.task_type}, status={self.status})>"


class QueueEntry(Base):
    """Queue entry for job processing with priority support."""

    __tablename__ = "queue"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    job_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("jobs.job_id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    priority: Mapped[int] = mapped_column(Integer, default=5, nullable=False)
    enqueued_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    dequeued_at: Mapped[Optional[int]] = mapped_column(BigInteger, nullable=True)
    worker_id: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    __table_args__ = (
        Index("idx_queue_priority_enqueued", "priority", "enqueued_at"),
        Index("idx_queue_dequeued_at", "dequeued_at"),
    )

    def __repr__(self) -> str:
        return f"<QueueEntry(job_id={self.job_id}, priority={self.priority})>"


class MediaStoreSyncStatus(Base):
    """Sync status tracking with media_store."""

    __tablename__ = "media_store_sync_status"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    job_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("jobs.job_id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    sync_attempted_at: Mapped[Optional[int]] = mapped_column(BigInteger, nullable=True)
    sync_completed_at: Mapped[Optional[int]] = mapped_column(BigInteger, nullable=True)
    sync_status: Mapped[str] = mapped_column(String, nullable=False, index=True)
    sync_error: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    retry_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    next_retry_at: Mapped[Optional[int]] = mapped_column(BigInteger, nullable=True, index=True)

    def __repr__(self) -> str:
        return f"<MediaStoreSyncStatus(job_id={self.job_id}, sync_status={self.sync_status})>"


__all__ = ["Job", "QueueEntry", "MediaStoreSyncStatus"]
