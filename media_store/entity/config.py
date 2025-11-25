from __future__ import annotations

import os
from pathlib import Path

# Database configuration
# Can be overridden with DATABASE_DIR and DATABASE_URL environment variables
DATABASE_DIR = os.getenv("DATABASE_DIR", "../data")
DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite:///{DATABASE_DIR}/media_store.db")

# Media storage configuration
# Can be overridden with MEDIA_STORAGE_DIR environment variable
MEDIA_STORAGE_DIR = os.getenv("MEDIA_STORAGE_DIR", f"{DATABASE_DIR}/media_store")

# Authentication configuration
# Path to the public key used for validating JWTs
PUBLIC_KEY_PATH = os.getenv("PUBLIC_KEY_PATH", f"{DATABASE_DIR}/public_key.pem")

# Authentication mode configuration
# Set AUTH_DISABLED=true to run in demo mode (no authentication required)
AUTH_DISABLED = os.getenv("AUTH_DISABLED", "false").lower() in ("true", "1", "yes")

# Read API authentication
# Set READ_AUTH_ENABLED=true to require authentication for read APIs
READ_AUTH_ENABLED = os.getenv("READ_AUTH_ENABLED", "false").lower() in ("true", "1", "yes")

# Ensure directories exist
Path(DATABASE_DIR).mkdir(parents=True, exist_ok=True)
Path(MEDIA_STORAGE_DIR).mkdir(parents=True, exist_ok=True)

__all__ = ["DATABASE_DIR", "DATABASE_URL", "MEDIA_STORAGE_DIR", "PUBLIC_KEY_PATH", "AUTH_DISABLED", "READ_AUTH_ENABLED"]


