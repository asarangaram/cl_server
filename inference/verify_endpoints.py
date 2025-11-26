"""Verification script for AI Inference Service API Endpoints."""

import asyncio
import logging
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

import httpx

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

SERVER_URL = "http://127.0.0.1:8001"
SERVER_PROCESS = None


async def start_server():
    """Start the inference server in a subprocess."""
    global SERVER_PROCESS
    logger.info("Starting inference server...")
    
    env = os.environ.copy()
    env["AUTH_DISABLED"] = "true"  # Disable auth for testing
    env["MEDIA_STORE_STUB"] = "true" # Use stub for media store
    
    # Run main.py
    SERVER_PROCESS = subprocess.Popen(
        [sys.executable, "main.py"],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    
    # Wait for server to start
    logger.info("Waiting for server to be ready...")
    async with httpx.AsyncClient() as client:
        for i in range(30):
            try:
                response = await client.get(f"{SERVER_URL}/health")
                if response.status_code == 200:
                    logger.info("✅ Server is ready")
                    return True
            except httpx.ConnectError:
                pass
            await asyncio.sleep(1)
            
    logger.error("❌ Server failed to start")
    if SERVER_PROCESS:
        stdout, stderr = SERVER_PROCESS.communicate()
        logger.error(f"Server STDOUT:\n{stdout}")
        logger.error(f"Server STDERR:\n{stderr}")
    return False



def stop_server():
    """Stop the inference server."""
    global SERVER_PROCESS
    if SERVER_PROCESS:
        logger.info("Stopping server...")
        SERVER_PROCESS.terminate()
        try:
            SERVER_PROCESS.wait(timeout=5)
        except subprocess.TimeoutExpired:
            SERVER_PROCESS.kill()
        logger.info("Server stopped")


async def verify_endpoints():
    """Verify API endpoints."""
    # Add dummy token for HTTPBearer dependency
    headers = {"Authorization": "Bearer dummy_token"}
    
    async with httpx.AsyncClient(base_url=SERVER_URL, timeout=10.0, headers=headers) as client:
        
        # 1. Health Check
        logger.info("\n--- Testing Health Check ---")
        resp = await client.get("/health")
        if resp.status_code == 200:
            data = resp.json()
            logger.info(f"✅ Health check passed: {data}")
        else:
            logger.error(f"❌ Health check failed: {resp.status_code}")
            return

        # 2. Create Job (Image Embedding)
        logger.info("\n--- Testing Create Job (Image Embedding) ---")
        media_store_id = str(int(time.time()))
        payload = {
            "media_store_id": media_store_id,
            "priority": 1
        }
        resp = await client.post("/job/image_embedding", json=payload)

        
        if resp.status_code == 201:
            job = resp.json()
            job_id = job["job_id"]
            logger.info(f"✅ Job created: {job_id}")
        else:
            logger.error(f"❌ Failed to create job: {resp.status_code} - {resp.text}")
            return

        # 3. Get Job Status
        logger.info(f"\n--- Testing Get Job Status ({job_id}) ---")
        # Poll for completion (worker should pick it up)
        for i in range(10):
            resp = await client.get(f"/job/{job_id}")
            if resp.status_code == 200:
                job = resp.json()
                status = job["status"]
                logger.info(f"Job status: {status}")
                
                if status == "completed":
                    logger.info(f"✅ Job completed successfully")
                    logger.info(f"Result: {job.get('result')}")
                    break
                elif status == "error":
                    logger.error(f"❌ Job failed: {job.get('error_message')}")
                    break
            else:
                logger.error(f"❌ Failed to get job: {resp.status_code}")
            
            await asyncio.sleep(2)

        # 4. Admin Stats
        logger.info("\n--- Testing Admin Stats ---")
        resp = await client.get("/admin/stats")
        if resp.status_code == 200:
            stats = resp.json()
            logger.info(f"✅ Stats retrieved: {stats}")
        else:
            logger.error(f"❌ Failed to get stats: {resp.status_code}")


async def main():
    try:
        if await start_server():
            await verify_endpoints()
    finally:
        stop_server()

if __name__ == "__main__":
    asyncio.run(main())
