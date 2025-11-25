from __future__ import annotations

import os
from pathlib import Path

# Database configuration
DATABASE_DIR = os.getenv("DATABASE_DIR", "./data")
DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite:///{DATABASE_DIR}/entities.db")

# Media storage configuration
MEDIA_STORAGE_DIR = os.getenv("MEDIA_STORAGE_DIR", "./media_files")

# Ensure directories exist
Path(DATABASE_DIR).mkdir(parents=True, exist_ok=True)
Path(MEDIA_STORAGE_DIR).mkdir(parents=True, exist_ok=True)

__all__ = ["DATABASE_DIR", "DATABASE_URL", "MEDIA_STORAGE_DIR"]
