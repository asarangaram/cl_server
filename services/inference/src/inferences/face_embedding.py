"""Face detection and embedding using RetinaFace + ArcFace (InsightFace)."""

from typing import Dict, Optional

import numpy as np
from cl_ml_tools import MLInference
from insightface.app import FaceAnalysis


class FaceEmbeddingInference(MLInference):
    """
    RetinaFace + ArcFace implementation for face detection and embedding.

    Uses InsightFace's FaceAnalysis which includes:
    - RetinaFace for face detection
    - Automatic face alignment using landmarks
    - ArcFace for 512-dimensional face embeddings
    """

    def __init__(
        self,
        det_size: tuple[int, int] = (640, 640),
        providers: Optional[list[str]] = None,
    ):
        """
        Initialize InsightFace face analysis pipeline.

        Args:
            det_size: Detection size (width, height) for face detector
            providers: ONNX Runtime providers (e.g., ['CUDAExecutionProvider', 'CPUExecutionProvider'])
        """
        self.det_size = det_size
        self.providers = providers or ['CPUExecutionProvider']

        print(f"Loading InsightFace (RetinaFace + ArcFace) with providers: {self.providers}...")

        # Initialize FaceAnalysis (includes detection + embedding)
        self.app = FaceAnalysis(providers=self.providers)
        self.app.prepare(ctx_id=0, det_size=det_size)

        self._input_size = (112, 112)  # Standard face crop size

        print(f"✓ InsightFace loaded successfully")

    @property
    def input_size(self) -> tuple[int, int]:
        """
        Returns the expected input size (width, height) for face crops.

        Returns:
            Tuple of (112, 112) - standard face size
        """
        return self._input_size

    def infer(self, buffer: np.ndarray, label: str) -> Optional[np.ndarray]:
        """
        Extract embedding from a cropped face image.

        Args:
            buffer: Image as numpy array (H, W, 3) in RGB or BGR format
            label: Label for logging

        Returns:
            512-d normalized face embedding, or None if validation fails
        """
        if buffer is None or buffer.size == 0:
            return None

        try:
            # Ensure correct format (InsightFace expects BGR)
            if buffer.shape[2] == 3:
                # Convert RGB to BGR if needed (InsightFace uses OpenCV convention)
                image_bgr = buffer[:, :, ::-1] if buffer.dtype == np.uint8 else buffer

            # Detect faces
            faces = self.app.get(image_bgr)

            # Validation: Must have exactly one face
            if not faces:
                print(f"Validation failed for {label}: No face detected")
                return None
            
            if len(faces) > 1:
                print(f"Validation failed for {label}: Multiple faces detected ({len(faces)})")
                return None

            # Get embedding from the single face
            # Note: We assume input is already a crop, so we don't crop again.
            # InsightFace's app.get() performs alignment and embedding on the detected face.
            embedding = faces[0].embedding

            # Already normalized by InsightFace (L2 norm = 1.0)
            return embedding.astype(np.float32)

        except Exception as e:
            print(f"Error processing {label}: {e}")
            return None


    def infer_batch(self, buffers: Dict[str, np.ndarray]) -> Dict[str, Optional[np.ndarray]]:
        """
        Process multiple images and extract face embeddings.

        Note: InsightFace doesn't have native batch processing,
        so we process images individually.

        Args:
            buffers: Dictionary mapping labels to image arrays

        Returns:
            Dictionary mapping labels to 512-d face embeddings or None
        """
        results = {}
        for label, buffer in buffers.items():
            results[label] = self.infer(buffer, label)
        return results

    def get_all_faces(self, buffer: np.ndarray) -> list[dict]:
        """
        Detect all faces in an image and return embeddings with metadata.

        Args:
            buffer: Image as numpy array (H, W, 3)

        Returns:
            List of dicts with 'embedding', 'bbox', 'landmarks', 'confidence'
        """
        if buffer is None or buffer.size == 0:
            return []

        try:
            # Convert to BGR
            image_bgr = buffer[:, :, ::-1] if buffer.dtype == np.uint8 else buffer

            # Detect all faces
            faces = self.app.get(image_bgr)

            results = []
            for idx, face in enumerate(faces):
                # Convert bbox from [x1, y1, x2, y2] to {x, y, width, height}
                x1, y1, x2, y2 = face.bbox
                bbox = {
                    "x": float(x1),
                    "y": float(y1),
                    "width": float(x2 - x1),
                    "height": float(y2 - y1),
                }

                results.append({
                    "face_index": idx,
                    "embedding": face.embedding.astype(np.float32),
                    "embedding_dimension": 512,
                    "bbox": bbox,
                    "landmarks": face.kps.tolist(),  # 5 facial landmarks
                    "confidence": float(face.det_score),
                })

            return results

        except Exception as e:
            print(f"Error detecting faces: {e}")
            return []


__all__ = ["FaceEmbeddingInference"]


if __name__ == "__main__":
    """Demo usage of InsightFace FaceEmbeddingInference."""
    print("\n" + "=" * 60)
    print("INSIGHTFACE (RetinaFace + ArcFace) DEMO")
    print("=" * 60)

    # Initialize inference engine
    inference = FaceEmbeddingInference(det_size=(640, 640))

    print(f"\nDetection size: {inference.det_size}")
    print(f"Providers: {inference.providers}")
    print(f"Face crop size: {inference.input_size}")
    print(f"Embedding dimension: 512")

    # Create a dummy face image (random for demo)
    print("\n1. Single face inference...")
    dummy_image = (np.random.rand(480, 640, 3) * 255).astype(np.uint8)
    embedding = inference.infer(dummy_image, label="test_face_1")

    if embedding is not None:
        print(f"   Generated embedding shape: {embedding.shape}")
        print(f"   Embedding dtype: {embedding.dtype}")
        print(f"   Embedding norm: {np.linalg.norm(embedding):.4f} (should be ~1.0)")
        print(f"   Sample values: {embedding[:5]}")
    else:
        print("   No face detected (expected with random image)")

    # Batch inference
    print("\n2. Batch inference...")
    buffers = {
        f"face_{i}": (np.random.rand(480, 640, 3) * 255).astype(np.uint8) for i in range(3)
    }

    embeddings = inference.infer_batch(buffers)

    print(f"   Processed {len(embeddings)} images")
    detected = sum(1 for emb in embeddings.values() if emb is not None)
    print(f"   Faces detected: {detected}/{len(embeddings)}")

    for label, emb in embeddings.items():
        if emb is not None:
            norm = np.linalg.norm(emb)
            print(f"   {label}: shape={emb.shape}, norm={norm:.4f}")

    # Demonstrate all faces detection
    print("\n3. Detecting all faces in image...")
    all_faces = inference.get_all_faces(dummy_image)
    print(f"   Total faces detected: {len(all_faces)}")

    for face in all_faces:
        print(f"   Face {face['face_index']}:")
        print(f"     BBox: {face['bbox']}")
        print(f"     Confidence: {face['confidence']:.4f}")
        print(f"     Embedding shape: {face['embedding'].shape}")

    print("\n" + "=" * 60)
    print("✅ Demo completed!")
    print("=" * 60)
    print("\nNOTE: Using production RetinaFace + ArcFace from InsightFace.")
    print("For real face images, detection and embedding will work properly.")
