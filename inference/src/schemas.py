"""Pydantic schemas for request/response validation."""

from __future__ import annotations

from typing import Any, Optional

from pydantic import BaseModel, Field, field_validator


class JobCreateRequest(BaseModel):
    """Request schema for creating a job."""

    media_store_id: str = Field(..., description="ID of the media in media_store")
    priority: int = Field(5, ge=0, le=10, description="Job priority (0-10, higher = more urgent)")


class JobResponse(BaseModel):
    """Response schema for job information."""

    job_id: str
    task_type: str
    media_store_id: str
    status: str
    priority: int
    created_at: int
    started_at: Optional[int] = None
    completed_at: Optional[int] = None
    error_message: Optional[str] = None
    result: Optional[dict[str, Any]] = None

    class Config:
        from_attributes = True


class CleanupRequest(BaseModel):
    """Request schema for cleanup operation."""

    older_than_seconds: Optional[int] = Field(None, ge=0, description="Delete jobs older than N seconds")
    status: str = Field("all", description="Filter by status: pending, completed, error, all")
    remove_results: bool = Field(True, description="Delete result files")
    remove_queue: bool = Field(True, description="Remove from queue")
    remove_orphaned_files: bool = Field(False, description="Delete files without DB entries")

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str) -> str:
        """Validate status filter."""
        allowed = {"pending", "processing", "completed", "error", "sync_failed", "all"}
        if v not in allowed:
            raise ValueError(f"Status must be one of {allowed}")
        return v


class CleanupResponse(BaseModel):
    """Response schema for cleanup operation."""

    jobs_deleted: int
    files_deleted: int
    queue_entries_removed: int


class StatsResponse(BaseModel):
    """Response schema for service statistics."""

    queue_size: int
    jobs: dict[str, int]
    storage: dict[str, Any]


class HealthResponse(BaseModel):
    """Response schema for health check."""

    status: str
    database: str
    worker: str
    queue_size: int


__all__ = [
    "JobCreateRequest",
    "JobResponse",
    "CleanupRequest",
    "CleanupResponse",
    "StatsResponse",
    "HealthResponse",
]
