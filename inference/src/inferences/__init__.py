"""ML Inference implementations package."""

from cl_ml_tools import MLInference

from .face_embedding import FaceEmbeddingInference
from .image_embedding import ImageEmbeddingInference

__all__ = ["MLInference", "ImageEmbeddingInference", "FaceEmbeddingInference"]

