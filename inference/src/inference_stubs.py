"""Stub inference implementations."""

from __future__ import annotations

import random
from typing import Any

import numpy as np
from PIL import Image


def generate_image_embedding(image: Image.Image) -> dict[str, Any]:
    """
    Generate image embedding (stubbed).

    Args:
        image: PIL Image

    Returns:
        Dict with embedding and dimension
    """
    # Stub: Return random 512-dimensional embedding
    embedding = np.random.randn(512).astype(np.float32)

    return {
        "embedding": embedding,
        "dimension": 512,
    }


def detect_faces(image: Image.Image) -> list[dict[str, Any]]:
    """
    Detect faces in image (stubbed).

    Args:
        image: PIL Image

    Returns:
        List of face detections with bboxes, landmarks, and crops
    """
    # Stub: Return 1-3 random face detections
    num_faces = random.randint(1, 3)
    width, height = image.size

    faces = []
    for i in range(num_faces):
        # Random bbox
        x = random.uniform(0, width * 0.5)
        y = random.uniform(0, height * 0.5)
        w = random.uniform(width * 0.1, width * 0.3)
        h = random.uniform(height * 0.1, height * 0.3)

        # Ensure bbox is within image
        x = max(0, min(x, width - w))
        y = max(0, min(y, height - h))

        # Create face crop
        crop = image.crop((int(x), int(y), int(x + w), int(y + h)))

        # Random landmarks
        landmarks = {
            "left_eye": [x + w * 0.3, y + h * 0.3],
            "right_eye": [x + w * 0.7, y + h * 0.3],
            "nose": [x + w * 0.5, y + h * 0.5],
            "left_mouth": [x + w * 0.35, y + h * 0.75],
            "right_mouth": [x + w * 0.65, y + h * 0.75],
        }

        faces.append(
            {
                "face_index": i,
                "bbox": {
                    "x": round(x, 2),
                    "y": round(y, 2),
                    "width": round(w, 2),
                    "height": round(h, 2),
                },
                "confidence": round(random.uniform(0.9, 0.99), 4),
                "landmarks": {k: [round(v[0], 2), round(v[1], 2)] for k, v in landmarks.items()},
                "crop": crop,
            }
        )

    return faces


def generate_face_embeddings(image: Image.Image) -> list[dict[str, Any]]:
    """
    Detect faces and generate embeddings (stubbed).

    Args:
        image: PIL Image

    Returns:
        List of face embeddings with bboxes, crops, and 512-d vectors
    """
    # First detect faces
    faces = detect_faces(image)

    # Add embeddings to each face
    for face in faces:
        face["embedding"] = np.random.randn(512).astype(np.float32)
        face["embedding_dimension"] = 512

    return faces


__all__ = ["generate_image_embedding", "detect_faces", "generate_face_embeddings"]
