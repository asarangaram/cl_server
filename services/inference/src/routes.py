"""API routes for the inference service."""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from .auth import require_admin, require_permission
from .database import get_db
from .job_service import JobService
from .schemas import (
    CleanupRequest,
    CleanupResponse,
    HealthResponse,
    JobCreateRequest,
    JobResponse,
    StatsResponse,
)

router = APIRouter()
logger = logging.getLogger(__name__)


@router.post("/job/{task_type}", status_code=status.HTTP_201_CREATED, response_model=JobResponse)
async def create_job(
    task_type: str,
    request: JobCreateRequest,
    db: Session = Depends(get_db),
    user: dict = Depends(require_permission("ai_inference_support")),
):
    """
    Create a new inference job.

    Requires `ai_inference_support` permission.

    Args:
        task_type: Type of inference (image_embedding, face_detection, face_embedding)
        request: Job creation request
        db: Database session
        user: Authenticated user from JWT

    Returns:
        Created job details

    Raises:
        400: Invalid task_type or priority
        409: Job already exists
    """
    service = JobService(db)

    try:
        job = service.create_job(
            task_type=task_type,
            media_store_id=request.media_store_id,
            priority=request.priority,
            created_by=user.get("sub"),
        )

        logger.info(
            "Job created",
            extra={
                "job_id": job.job_id,
                "user_id": user.get("sub"),
                "task_type": task_type,
                "media_store_id": request.media_store_id,
                "priority": request.priority,
            },
        )

        return job

    except ValueError as e:
        if "already exists" in str(e):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/job/{job_id}", response_model=JobResponse)
async def get_job(
    job_id: str,
    db: Session = Depends(get_db),
):
    """
    Get job status and results.

    No authentication required - job_id acts as capability token.

    Args:
        job_id: Job identifier
        db: Database session

    Returns:
        Job details

    Raises:
        404: Job not found
    """
    service = JobService(db)
    job = service.get_job(job_id)

    if job is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")

    return job


@router.delete("/job/{job_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_job(
    job_id: str,
    db: Session = Depends(get_db),
    user: dict = Depends(require_permission("ai_inference_support")),
):
    """
    Delete job and all associated data.

    Requires `ai_inference_support` permission.

    Args:
        job_id: Job identifier
        db: Database session
        user: Authenticated user from JWT

    Raises:
        404: Job not found
    """
    service = JobService(db)
    deleted = service.delete_job(job_id)

    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")

    logger.info(
        "Job deleted",
        extra={
            "job_id": job_id,
            "user_id": user.get("sub"),
        },
    )


@router.delete("/admin/cleanup", response_model=CleanupResponse)
async def cleanup(
    filters: CleanupRequest,
    db: Session = Depends(get_db),
    admin: dict = Depends(require_admin),
):
    """
    Bulk cleanup of jobs and artifacts.

    Requires admin access.

    Args:
        filters: Cleanup filters
        db: Database session
        admin: Authenticated admin user

    Returns:
        Cleanup statistics
    """
    # TODO: Implement cleanup logic
    logger.info(
        "Cleanup requested",
        extra={
            "user_id": admin.get("sub"),
            "filters": filters.model_dump(),
        },
    )

    return CleanupResponse(
        jobs_deleted=0,
        files_deleted=0,
        queue_entries_removed=0,
    )


@router.get("/admin/stats", response_model=StatsResponse)
async def get_stats(
    db: Session = Depends(get_db),
    admin: dict = Depends(require_admin),
):
    """
    Get service statistics.

    Requires admin access.

    Args:
        db: Database session
        admin: Authenticated admin user

    Returns:
        Service statistics
    """
    from .models import Job
    from .queue import Queue

    queue = Queue(db)

    # Get job counts by status
    job_counts = {}
    for status_val in ["pending", "processing", "completed", "error", "sync_failed"]:
        count = db.query(Job).filter_by(status=status_val).count()
        job_counts[status_val] = count

    return StatsResponse(
        queue_size=queue.size(),
        jobs=job_counts,
        storage={"total_jobs": db.query(Job).count(), "disk_usage_mb": 0.0},
    )


@router.get("/health", response_model=HealthResponse)
async def health_check(db: Session = Depends(get_db)):
    """
    Health check endpoint.

    No authentication required.

    Args:
        db: Database session

    Returns:
        Health status
    """
    from .queue import Queue

    try:
        queue = Queue(db)
        queue_size = queue.size()
        database_status = "connected"
    except Exception:
        database_status = "error"
        queue_size = 0

    return HealthResponse(
        status="healthy" if database_status == "connected" else "unhealthy",
        database=database_status,
        worker="unknown",  # TODO: Implement worker status check
        queue_size=queue_size,
    )

class RootResponse(BaseModel):
    message: str

@router.get(
    "/",
    summary="Root",
    description="Returns a simple welcome string",
    response_model=RootResponse,
    operation_id="root_get",
)
async def root():
    return RootResponse(message="inference service is running")

__all__ = ["router"]

