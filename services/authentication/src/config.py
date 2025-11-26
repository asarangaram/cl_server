from __future__ import annotations

import os
from pathlib import Path

# Database configuration
DATABASE_DIR = os.getenv("DATABASE_DIR", "../data")
DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite:///{DATABASE_DIR}/user_auth.db")

# Auth configuration
SECRET_KEY = os.getenv("SECRET_KEY", "dev_secret_key_change_in_production")
ALGORITHM = "ES256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))

# Admin configuration
ADMIN_USERNAME = os.getenv("ADMIN_USERNAME", "admin")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "admin")

# Ensure directories exist
Path(DATABASE_DIR).mkdir(parents=True, exist_ok=True)

__all__ = [
    "DATABASE_DIR", 
    "DATABASE_URL", 
    "SECRET_KEY", 
    "ALGORITHM", 
    "ACCESS_TOKEN_EXPIRE_MINUTES",
    "ADMIN_USERNAME",
    "ADMIN_PASSWORD"
]
