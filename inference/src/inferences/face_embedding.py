"""Face embedding inference implementation."""

from typing import Dict, Optional

import numpy as np
from cl_ml_tools import MLInference



class FaceEmbeddingInference(MLInference):
    """
    Stub implementation for face embedding inference.

    This class provides a placeholder implementation that generates random
    512-dimensional face embeddings. Replace with actual model inference in production.
    """

    def __init__(self, embedding_dim: int = 512, input_size: tuple[int, int] = (112, 112)):
        """
        Initialize face embedding inference.

        Args:
            embedding_dim: Dimension of output embeddings (default 512)
            input_size: Expected input size as (width, height) (default 112x112 for faces)
        """
        self._embedding_dim = embedding_dim
        self._input_size = input_size

    @property
    def input_size(self) -> tuple[int, int]:
        """
        Returns the expected input size (width, height) for the model.

        Returns:
            Tuple of (width, height)
        """
        return self._input_size

    def infer(self, buffer: np.ndarray, label: str) -> Optional[np.ndarray]:
        """
        Process a single pre-processed face buffer and return its embedding.

        Args:
            buffer: The pre-processed face crop data as a NumPy array
            label: The label of the data (for logging, e.g., "face_0")

        Returns:
            A 512-d numpy array representing the face embedding, or None if it cannot be computed
        """
        # Stub: Generate random face embedding
        # TODO: Replace with actual face recognition model inference
        # Example: return self.face_model.predict(buffer)

        if buffer is None or buffer.size == 0:
            return None

        # Generate random 512-d face embedding (stub)
        embedding = np.random.randn(self._embedding_dim).astype(np.float32)

        # Normalize embedding (common in face recognition)
        embedding = embedding / np.linalg.norm(embedding)

        return embedding

    def infer_batch(self, buffers: Dict[str, np.ndarray]) -> Dict[str, Optional[np.ndarray]]:
        """
        Process a dictionary of pre-processed face buffers and return their embeddings.

        Args:
            buffers: A dictionary where keys are string labels (e.g., "face_0", "face_1")
                     and values are pre-processed face crop data as NumPy arrays

        Returns:
            A dictionary mapping each label to its computed 512-d face embedding, or None
        """
        # Stub: Process each face individually
        # TODO: Replace with batched model inference for better performance
        # Example: return self.face_model.predict_batch(list(buffers.values()))

        results = {}
        for label, buffer in buffers.items():
            results[label] = self.infer(buffer, label)

        return results


__all__ = ["FaceEmbeddingInference"]


if __name__ == "__main__":
    """Demo usage of FaceEmbeddingInference."""
    print("\n" + "=" * 60)
    print("FACE EMBEDDING INFERENCE DEMO")
    print("=" * 60)

    # Initialize inference engine
    inference = FaceEmbeddingInference(embedding_dim=512, input_size=(112, 112))

    print(f"\nInput size: {inference.input_size}")
    print(f"Embedding dimension: 512")

    # Single inference
    print("\n1. Single face inference...")
    dummy_face = np.random.randn(112, 112, 3).astype(np.float32)
    embedding = inference.infer(dummy_face, label="face_0")

    if embedding is not None:
        print(f"   Generated embedding shape: {embedding.shape}")
        print(f"   Embedding dtype: {embedding.dtype}")
        print(f"   Embedding norm: {np.linalg.norm(embedding):.4f} (should be ~1.0)")
        print(f"   Sample values: {embedding[:5]}")

    # Batch inference
    print("\n2. Batch inference (multiple faces)...")
    buffers = {f"face_{i}": np.random.randn(112, 112, 3).astype(np.float32) for i in range(5)}

    embeddings = inference.infer_batch(buffers)

    print(f"   Processed {len(embeddings)} faces")
    for label, emb in embeddings.items():
        if emb is not None:
            norm = np.linalg.norm(emb)
            print(f"   {label}: shape={emb.shape}, dtype={emb.dtype}, norm={norm:.4f}")

    # Demonstrate similarity computation
    print("\n3. Computing face similarity...")
    if len(embeddings) >= 2:
        labels = list(embeddings.keys())
        emb1 = embeddings[labels[0]]
        emb2 = embeddings[labels[1]]

        if emb1 is not None and emb2 is not None:
            # Cosine similarity (dot product of normalized vectors)
            similarity = np.dot(emb1, emb2)
            print(f"   Similarity between {labels[0]} and {labels[1]}: {similarity:.4f}")
            print(f"   (Range: -1 to 1, higher = more similar)")

    print("\n" + "=" * 60)
    print("✅ Demo completed!")
    print("=" * 60)
    print("\nNOTE: This is a stub implementation using random embeddings.")
    print("Replace with actual face recognition model (e.g., ArcFace, FaceNet) in production.")
