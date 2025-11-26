"""
Inference Service CLI Clients

This package provides command-line interfaces for interacting with the inference microservice.

Workflows supported:
- image_embedding: Generate vector embeddings for images
- face_detection: Detect faces in images

Usage:
    python image_embedding_client.py <image_path> --media-store <host>:<port>
    python face_detection_client.py <image_path> --media-store <host>:<port>
"""

__version__ = "0.1.0"
__all__ = ["base_client", "utils"]
