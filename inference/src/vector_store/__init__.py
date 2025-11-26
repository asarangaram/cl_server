"""Vector store package for image and face embeddings."""

from cl_ml_tools import StoreInterface

from .face_store import QdrantFaceStore
from .image_store import QdrantImageStore

__all__ = ["StoreInterface", "QdrantImageStore", "QdrantFaceStore"]

