"""AI Inference Microservice configuration."""

from __future__ import annotations

import os
from pathlib import Path

# Database configuration
DATABASE_DIR = os.getenv("DATABASE_DIR", "../data")
DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite:///{DATABASE_DIR}/inference.db")

# Storage configuration
STORAGE_DIR = os.getenv("STORAGE_DIR", f"{DATABASE_DIR}/inference/jobs")

# Authentication configuration
PUBLIC_KEY_PATH = os.getenv("PUBLIC_KEY_PATH", f"{DATABASE_DIR}/public_key.pem")
AUTH_DISABLED = os.getenv("AUTH_DISABLED", "false").lower() in ("true", "1", "yes")

# Worker configuration
WORKER_POLL_INTERVAL = int(os.getenv("WORKER_POLL_INTERVAL", "5"))  # seconds
WORKER_MAX_RETRIES = int(os.getenv("WORKER_MAX_RETRIES", "3"))

# Vector store configuration
QDRANT_URL = os.getenv("QDRANT_URL", "http://localhost:6333")

# Broadcasting configuration
BROADCAST_TYPE = os.getenv("BROADCAST_TYPE", "mqtt")  # mqtt, sse, or none
MQTT_BROKER = os.getenv("MQTT_BROKER", "localhost")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
MQTT_TOPIC = os.getenv("MQTT_TOPIC", "inference/events")

# Media Store configuration
MEDIA_STORE_URL = os.getenv("MEDIA_STORE_URL", "http://localhost:8000")
MEDIA_STORE_STUB = os.getenv("MEDIA_STORE_STUB", "true").lower() in ("true", "1", "yes")

# Logging configuration
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")

# Ensure directories exist
Path(DATABASE_DIR).mkdir(parents=True, exist_ok=True)
Path(STORAGE_DIR).mkdir(parents=True, exist_ok=True)

__all__ = [
    "DATABASE_DIR",
    "DATABASE_URL",
    "STORAGE_DIR",
    "PUBLIC_KEY_PATH",
    "AUTH_DISABLED",
    "WORKER_POLL_INTERVAL",
    "WORKER_MAX_RETRIES",
    "BROADCAST_TYPE",
    "MQTT_BROKER",
    "MQTT_PORT",
    "MQTT_TOPIC",
    "MEDIA_STORE_URL",
    "MEDIA_STORE_STUB",
    "LOG_LEVEL",
]
