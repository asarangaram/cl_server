"""Complete end-to-end test with MQTT."""

import asyncio
import json
import os
import time

# Set environment
os.environ["MEDIA_STORE_STUB"] = "true"
os.environ["BROADCAST_TYPE"] = "mqtt"

import logging
logging.basicConfig(level=logging.DEBUG)

import paho.mqtt.client as mqtt

from src.database import SessionLocal
from src.job_service import JobService
from src.worker import Worker
from src.config import BROADCAST_TYPE
from src.broadcaster import get_broadcaster

print(f"DEBUG: BROADCAST_TYPE from config = {BROADCAST_TYPE}")
broadcaster = get_broadcaster()
print(f"DEBUG: Broadcaster enabled = {broadcaster.enabled}")

# MQTT setup
mqtt_received = asyncio.Event()
mqtt_data = {}

def on_connect(client, userdata, flags, rc, properties=None):
    print(f"✅ MQTT Connected")
    client.subscribe("inference/events")

def on_message(client, userdata, msg):
    global mqtt_data
    try:
        payload = json.loads(msg.payload.decode())
        print(f"\n📨 Received MQTT event: {payload['event']}")
        mqtt_data = payload
        mqtt_received.set()
    except Exception as e:
        print(f"Error: {e}")

async def main():
    # Start MQTT client
    client = mqtt.Client(protocol=mqtt.MQTTv5)
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect("localhost", 1883, 60)
    client.loop_start()
    
    await asyncio.sleep(1)
    
    # Create job
    print("\n1. Creating job...")
    db = SessionLocal()
    service = JobService(db)
    
    media_store_id = str(int(time.time()))
    job = service.create_job(
        task_type="image_embedding",
        media_store_id=media_store_id,
        priority=10
    )
    job_id = job.job_id
    print(f"✅ Job created: {job_id}")
    db.close()
    
    # Process job with worker
    print("\n2. Processing job with worker...")
    worker = Worker()
    db = SessionLocal()
    try:
        await worker.process_job(job_id, db)
        print("✅ Job processing completed")
    except Exception as e:
        print(f"❌ Job processing failed: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()
    
    # Wait for MQTT event
    print("\n3. Waiting for MQTT event...")
    try:
        await asyncio.wait_for(mqtt_received.wait(), timeout=5.0)
        print(f"✅ Received MQTT event!")
        print(f"Event: {mqtt_data.get('event')}")
        print(f"Job ID: {mqtt_data.get('data', {}).get('job_id')}")
        print(f"Status: {mqtt_data.get('data', {}).get('status')}")
    except asyncio.TimeoutError:
        print("❌ Timed out waiting for MQTT event")
    
    client.loop_stop()
    client.disconnect()

if __name__ == "__main__":
    asyncio.run(main())
