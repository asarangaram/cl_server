"""AI Inference Microservice."""

from __future__ import annotations

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .database import engine, init_db
from .models import Base
from .qdrant_manager import QdrantManager
from .routes import router

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize database tables
try:
    init_db()
    logger.info("Database tables initialized successfully")
except Exception as e:
    logger.error(f"Failed to initialize database: {e}", exc_info=True)

# Create FastAPI app
app = FastAPI(
    title="AI Inference Microservice",
    description="Asynchronous inference service for image and face processing",
    version="0.1.0",
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from .routes import router

app.include_router(router)

__all__ = ["app"]

