"""Verification script for Image Embedding Flow with MQTT Broadcasting.

Prerequisites:
    - Mosquitto MQTT broker must be running on localhost:1883
    - Install: brew install mosquitto
    - Start: brew services start mosquitto
"""

import asyncio
import json
import logging
import os
import subprocess
import sys
import time
from typing import Optional

import httpx
import paho.mqtt.client as mqtt
from qdrant_client import QdrantClient

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

SERVER_URL = "http://127.0.0.1:8001"
MQTT_BROKER = "localhost"
MQTT_PORT = 1883
MQTT_TOPIC = "inference/events"
QDRANT_URL = "http://localhost:6333"

SERVER_PROCESS = None
WORKER_PROCESS = None
JOB_COMPLETED = asyncio.Event()
COMPLETED_JOB_DATA = {}


def on_connect(client, userdata, flags, rc, properties=None):
    """Callback for MQTT connection."""
    if rc == 0:
        logger.info("✅ Connected to MQTT broker")
        client.subscribe(MQTT_TOPIC)
    else:
        logger.error(f"❌ Failed to connect to MQTT broker: {rc}")


def on_message(client, userdata, msg):
    """Callback for MQTT message."""
    try:
        payload = json.loads(msg.payload.decode())
        event = payload.get("event")
        data = payload.get("data")
        
        logger.info(f"📨 Received MQTT event: {event}")
        
        if event == "job_completed":
            global COMPLETED_JOB_DATA
            COMPLETED_JOB_DATA = data
            JOB_COMPLETED.set()
            
    except Exception as e:
        logger.error(f"Error parsing MQTT message: {e}")


async def start_server():
    """Start the inference server."""
    global SERVER_PROCESS
    logger.info("Starting inference server...")
    
    env = os.environ.copy()
    env["AUTH_DISABLED"] = "true"
    env["MEDIA_STORE_STUB"] = "true"
    env["BROADCAST_TYPE"] = "mqtt"
    
    SERVER_PROCESS = subprocess.Popen(
        [sys.executable, "main.py"],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    
    # Wait for ready
    async with httpx.AsyncClient() as client:
        for i in range(30):
            try:
                resp = await client.get(f"{SERVER_URL}/health")
                if resp.status_code == 200:
                    logger.info("✅ Server is ready")
                    return True
            except:
                pass
            await asyncio.sleep(1)
            
    logger.error("❌ Server failed to start")
    return False


async def start_worker():
    """Start the worker process."""
    global WORKER_PROCESS
    logger.info("Starting worker...")
    
    env = os.environ.copy()
    env["MEDIA_STORE_STUB"] = "true"
    env["BROADCAST_TYPE"] = "mqtt"
    
    WORKER_PROCESS = subprocess.Popen(
        [sys.executable, "-m", "src.worker"],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    
    # Wait for worker to initialize ML models
    await asyncio.sleep(10)
    logger.info("✅ Worker started")
    return True


def stop_server():
    """Stop the server."""
    if SERVER_PROCESS:
        SERVER_PROCESS.terminate()
        try:
            SERVER_PROCESS.wait(timeout=5)
        except:
            SERVER_PROCESS.kill()
        logger.info("Server stopped")


def stop_worker():
    """Stop the worker."""
    if WORKER_PROCESS:
        WORKER_PROCESS.terminate()
        try:
            WORKER_PROCESS.wait(timeout=5)
        except:
            WORKER_PROCESS.kill()
        logger.info("Worker stopped")


async def verify_flow():
    """Verify the full flow."""
    # 1. Setup MQTT Client
    client = mqtt.Client(protocol=mqtt.MQTTv5)
    client.on_connect = on_connect
    client.on_message = on_message
    
    try:
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        client.loop_start()
    except Exception as e:
        logger.error(f"❌ Failed to connect to MQTT broker: {e}")
        return

    async with httpx.AsyncClient(base_url=SERVER_URL, timeout=10.0) as http_client:
        # 2. Create Job
        media_store_id = str(int(time.time()))
        logger.info(f"\n--- 1. Creating Job (ID: {media_store_id}) ---")
        
        # Add dummy auth header
        headers = {"Authorization": "Bearer dummy"}
        
        payload = {
            "media_store_id": media_store_id,
            "priority": 10
        }
        
        resp = await http_client.post("/job/image_embedding", json=payload, headers=headers)
        if resp.status_code != 201:
            logger.error(f"❌ Failed to create job: {resp.text}")
            return
            
        job_id = resp.json()["job_id"]
        logger.info(f"✅ Job created: {job_id}")
        
        # 3. Wait for MQTT Event
        logger.info("\n--- 2. Waiting for MQTT Completion Event (timeout: 60s) ---")
        try:
            await asyncio.wait_for(JOB_COMPLETED.wait(), timeout=60.0)
            logger.info("✅ Received completion event!")
            logger.info(f"Event Data: {COMPLETED_JOB_DATA}")
            
            if COMPLETED_JOB_DATA["job_id"] != job_id:
                logger.error("❌ Mismatch in job ID")
                return
                
        except asyncio.TimeoutError:
            logger.error("❌ Timed out waiting for MQTT event")
            return

        # 4. Verify Qdrant
        logger.info("\n--- 3. Verifying Vector Store ---")
        try:
            qdrant = QdrantClient(url=QDRANT_URL)
            points = qdrant.retrieve(
                collection_name="image_embeddings",
                ids=[int(media_store_id)],
                with_payload=True,
                with_vectors=True
            )
            
            if points:
                point = points[0]
                logger.info(f"✅ Found point in Qdrant: {point.id}")
                logger.info(f"Payload: {point.payload}")
                logger.info(f"Vector length: {len(point.vector)}")
                
                if point.payload.get("job_id") == job_id:
                    logger.info("✅ Payload matches job ID")
                else:
                    logger.error("❌ Payload job ID mismatch")
            else:
                logger.error("❌ Point not found in Qdrant")
                
        except Exception as e:
            logger.error(f"❌ Qdrant verification failed: {e}")

    client.loop_stop()
    client.disconnect()


async def main():
    """Main entry point."""
    logger.info("=" * 60)
    logger.info("MQTT Flow Verification")
    logger.info("=" * 60)
    logger.info("Prerequisites:")
    logger.info("  - Mosquitto MQTT broker running on localhost:1883")
    logger.info("  - Qdrant running on localhost:6333")
    logger.info("=" * 60)
    
    try:
        if await start_server() and await start_worker():
            await verify_flow()
    finally:
        stop_worker()
        stop_server()

if __name__ == "__main__":
    asyncio.run(main())
