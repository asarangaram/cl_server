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

# Ensure directories exist
Path(DATABASE_DIR).mkdir(parents=True, exist_ok=True)
Path(MEDIA_STORAGE_DIR).mkdir(parents=True, exist_ok=True)

__all__ = ["DATABASE_DIR", "DATABASE_URL", "MEDIA_STORAGE_DIR"]

