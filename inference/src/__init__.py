"""FastAPI application initialization."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="AI Inference Microservice",
    description="Asynchronous AI inference service for image processing",
    version="0.1.0",
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "service": "AI Inference Microservice",
        "version": "0.1.0",
        "status": "running",
    }


# Import and include routers
from .routes import router

app.include_router(router)

__all__ = ["app"]

