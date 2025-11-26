"""Face detection using RetinaFace (InsightFace)."""

from typing import Optional

import numpy as np
from insightface.app import FaceAnalysis


class FaceDetectionInference:
    """
    RetinaFace implementation for face detection.

    Uses InsightFace's FaceAnalysis for robust face detection with landmarks.
    """

    def __init__(
        self,
        det_size: tuple[int, int] = (640, 640),
        providers: Optional[list[str]] = None,
    ):
        """
        Initialize RetinaFace face detection.

        Args:
            det_size: Detection size (width, height) for face detector
            providers: ONNX Runtime providers
        """
        self.det_size = det_size
        self.providers = providers or ['CPUExecutionProvider']

        print(f"Loading RetinaFace with providers: {self.providers}...")

        # Initialize FaceAnalysis (detection only, no embedding)
        self.app = FaceAnalysis(providers=self.providers)
        self.app.prepare(ctx_id=0, det_size=det_size)

        print(f"✓ RetinaFace loaded successfully")

    def detect_faces(self, image: np.ndarray) -> list[dict]:
        """
        Detect all faces in an image.

        Args:
            image: Image as numpy array (H, W, 3) in RGB or BGR format

        Returns:
            List of dicts with 'bbox', 'landmarks', 'confidence', 'face_index'
        """
        if image is None or image.size == 0:
            return []

        try:
            # Convert to BGR if needed
            image_bgr = image[:, :, ::-1] if image.dtype == np.uint8 else image

            # Detect faces
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
                    "bbox": bbox,
                    "landmarks": face.kps.tolist(),  # 5 facial landmarks
                    "confidence": float(face.det_score),
                })

            return results

        except Exception as e:
            print(f"Error detecting faces: {e}")
            return []


__all__ = ["FaceDetectionInference"]


if __name__ == "__main__":
    """Demo usage of RetinaFace FaceDetectionInference."""
    print("\n" + "=" * 60)
    print("RETINAFACE FACE DETECTION DEMO")
    print("=" * 60)

    # Initialize detector
    detector = FaceDetectionInference(det_size=(640, 640))

    print(f"\nDetection size: {detector.det_size}")
    print(f"Providers: {detector.providers}")

    # Test with dummy image
    print("\n1. Detecting faces in image...")
    dummy_image = (np.random.rand(480, 640, 3) * 255).astype(np.uint8)
    faces = detector.detect_faces(dummy_image)

    print(f"   Total faces detected: {len(faces)}")

    for face in faces:
        print(f"\n   Face {face['face_index']}:")
        print(f"     BBox: {face['bbox']}")
        print(f"     Confidence: {face['confidence']:.4f}")
        print(f"     Landmarks: {len(face['landmarks'])} points")

    if not faces:
        print("   No faces detected (expected with random image)")

    print("\n" + "=" * 60)
    print("✅ Demo completed!")
    print("=" * 60)
    print("\nNOTE: Using production RetinaFace from InsightFace.")
    print("For real face images, detection will work properly.")
