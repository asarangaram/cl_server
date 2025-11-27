"""AI Inference Microservice configuration."""

from __future__ import annotations

import os
from pathlib import Path

# CL_SERVER_DIR is required - root directory for all persistent data
CL_SERVER_DIR = os.getenv("CL_SERVER_DIR")
if not CL_SERVER_DIR:
    raise ValueError("CL_SERVER_DIR environment variable must be set")

# Check write permission
if not os.access(CL_SERVER_DIR, os.W_OK):
    raise ValueError(f"CL_SERVER_DIR does not exist or no write permission: {CL_SERVER_DIR}")

# Database configuration
# Derived from CL_SERVER_DIR; can be overridden with DATABASE_URL environment variable
DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite:///{CL_SERVER_DIR}/inference.db")

# Storage configuration
# Derived from CL_SERVER_DIR; can be overridden with STORAGE_DIR environment variable
STORAGE_DIR = os.getenv("STORAGE_DIR", f"{CL_SERVER_DIR}/inference/jobs")

# Authentication configuration
# Derived from CL_SERVER_DIR; can be overridden with PUBLIC_KEY_PATH environment variable
PUBLIC_KEY_PATH = os.getenv("PUBLIC_KEY_PATH", f"{CL_SERVER_DIR}/public_key.pem")
AUTH_DISABLED = os.getenv("AUTH_DISABLED", "false").lower() in ("true", "1", "yes")

# Vector store configuration
# Derived from CL_SERVER_DIR; can be overridden with VECTOR_STORE_PATH environment variable
VECTOR_STORE_PATH = os.getenv("VECTOR_STORE_PATH", f"{CL_SERVER_DIR}/vector_store/qdrant")

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

__all__ = [
    "CL_SERVER_DIR",
    "DATABASE_URL",
    "STORAGE_DIR",
    "PUBLIC_KEY_PATH",
    "VECTOR_STORE_PATH",
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
