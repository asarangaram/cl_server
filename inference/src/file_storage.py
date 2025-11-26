"""File storage utilities for job artifacts."""

from __future__ import annotations

import shutil
from pathlib import Path
from typing import Optional

import numpy as np
from PIL import Image

from .config import STORAGE_DIR


class FileStorage:
    """Manages file storage for job artifacts."""

    def __init__(self, base_dir: Optional[str] = None):
        """
        Initialize file storage.

        Args:
            base_dir: Base directory for storage (defaults to config.STORAGE_DIR)
        """
        self.base_dir = Path(base_dir or STORAGE_DIR)
        self.base_dir.mkdir(parents=True, exist_ok=True)

    def save_embedding(self, job_id: str, embedding: np.ndarray) -> str:
        """
        Save embedding and return relative path.

        Args:
            job_id: Job identifier
            embedding: NumPy array to save

        Returns:
            Relative path to saved file
        """
        path = self.base_dir / job_id / "embedding.bin"
        path.parent.mkdir(parents=True, exist_ok=True)
        np.save(path, embedding)
        return str(path.relative_to(self.base_dir))

    def save_face_crop(self, job_id: str, face_index: int, image: Image.Image) -> str:
        """
        Save face crop and return relative path.

        Args:
            job_id: Job identifier
            face_index: Index of the face
            image: PIL Image to save

        Returns:
            Relative path to saved file
        """
        path = self.base_dir / job_id / "faces" / f"{face_index}.jpg"
        path.parent.mkdir(parents=True, exist_ok=True)
        image.save(path, "JPEG", quality=95)
        return str(path.relative_to(self.base_dir))

    def save_face_embedding(self, job_id: str, face_index: int, embedding: np.ndarray) -> str:
        """
        Save face embedding and return relative path.

        Args:
            job_id: Job identifier
            face_index: Index of the face
            embedding: NumPy array to save

        Returns:
            Relative path to saved file
        """
        path = self.base_dir / job_id / "faces" / f"{face_index}.bin"
        path.parent.mkdir(parents=True, exist_ok=True)
        np.save(path, embedding)
        return str(path.relative_to(self.base_dir))

    def delete_job_files(self, job_id: str) -> bool:
        """
        Delete all files for a job.

        Args:
            job_id: Job identifier

        Returns:
            True if deleted, False if directory didn't exist
        """
        job_dir = self.base_dir / job_id
        if job_dir.exists():
            shutil.rmtree(job_dir)
            return True
        return False

    def get_job_dir(self, job_id: str) -> Path:
        """
        Get job directory path.

        Args:
            job_id: Job identifier

        Returns:
            Path to job directory
        """
        return self.base_dir / job_id


__all__ = ["FileStorage"]
