"""Test script to run worker with a single job and capture all output."""

import asyncio
import logging
import os
import sys

# Set environment
os.environ["MEDIA_STORE_STUB"] = "true"
os.environ["BROADCAST_TYPE"] = "mqtt"

# Configure detailed logging
logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)

from src.database import SessionLocal
from src.models import Job
from src.worker import Worker

async def test_worker():
    """Test worker with existing job."""
    # Get a stuck job
    db = SessionLocal()
    job = db.query(Job).filter_by(status="processing").first()
    
    if not job:
        print("No processing jobs found")
        db.close()
        return
    
    # Cache job attributes before closing session
    job_id = job.job_id
    task_type = job.task_type
    media_store_id = job.media_store_id
    
    print(f"Testing with job: {job_id}")
    print(f"Task type: {task_type}")
    print(f"Media store ID: {media_store_id}")
    
    # Reset job to pending
    job.status = "pending"
    job.started_at = None
    db.commit()
    db.close()
    
    # Create worker and process one job
    worker = Worker()
    
    # Test broadcaster
    from src.broadcaster import get_broadcaster
    from src.config import BROADCAST_TYPE
    print(f"\nBROADCAST_TYPE={BROADCAST_TYPE}")
    broadcaster = get_broadcaster()
    print(f"Broadcaster enabled: {broadcaster.enabled}")
    print(f"Broadcaster client: {broadcaster.client}")
    
    # Get new session
    db = SessionLocal()
    try:
        await worker.process_job(job_id, db)
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    asyncio.run(test_worker())
