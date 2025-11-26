"""Image embedding inference using CLIP ViT-B/32."""

from typing import Dict, Optional

import numpy as np
import torch
from cl_ml_tools import MLInference
from PIL import Image
from transformers import CLIPModel, CLIPProcessor


class ImageEmbeddingInference(MLInference):
    """
    CLIP ViT-B/32 implementation for image embedding inference.

    Uses OpenAI's CLIP model to generate 512-dimensional embeddings
    suitable for image similarity search and retrieval.
    """

    def __init__(
        self,
        model_name: str = "openai/clip-vit-base-patch32",
        device: Optional[str] = None,
    ):
        """
        Initialize CLIP image embedding inference.

        Args:
            model_name: Hugging Face model identifier
            device: Device to run on ('cuda', 'cpu', or None for auto-detect)
        """
        self.device = device or ("cuda" if torch.cuda.is_available() else "cpu")
        self.model_name = model_name

        print(f"Loading CLIP model: {model_name} on {self.device}...")
        # Use safetensors to avoid torch.load security issues
        self.model = CLIPModel.from_pretrained(model_name, use_safetensors=True).to(self.device)
        self.processor = CLIPProcessor.from_pretrained(model_name, use_safetensors=True)


        self.model.eval()  # Set to evaluation mode
        self._input_size = (224, 224)

        print(f"✓ CLIP model loaded successfully")

    @property
    def input_size(self) -> tuple[int, int]:
        """
        Returns the expected input size (width, height) for the model.

        Returns:
            Tuple of (224, 224) for CLIP ViT-B/32
        """
        return self._input_size

    def infer(self, buffer: np.ndarray, label: str) -> Optional[np.ndarray]:
        """
        Process a single image and return its CLIP embedding.

        Args:
            buffer: Image as numpy array (H, W, 3) in RGB format
            label: Label for logging

        Returns:
            512-d normalized numpy array representing the embedding, or None if processing fails
        """
        if buffer is None or buffer.size == 0:
            return None

        try:
            # Convert numpy array to PIL Image if needed
            if isinstance(buffer, np.ndarray):
                # Ensure uint8 format
                if buffer.dtype != np.uint8:
                    buffer = (buffer * 255).astype(np.uint8) if buffer.max() <= 1.0 else buffer.astype(np.uint8)
                image = Image.fromarray(buffer)
            else:
                image = buffer

            # Process image
            # Manually resize to avoid processor issues
            if isinstance(image, Image.Image):
                image = image.resize((224, 224), Image.Resampling.LANCZOS)

            # Wrap in list to ensure consistent batch processing
            inputs = self.processor(images=[image], return_tensors="pt", padding=True).to(self.device)

            # Generate embedding
            with torch.no_grad():
                image_features = self.model.get_image_features(**inputs)

            # Convert to numpy and normalize
            embedding = image_features.cpu().numpy()[0]
            embedding = embedding / np.linalg.norm(embedding)

            return embedding.astype(np.float32)

        except Exception as e:
            print(f"Error processing {label}: {e}")
            return None

    def infer_batch(self, buffers: Dict[str, np.ndarray]) -> Dict[str, Optional[np.ndarray]]:
        """
        Process a batch of images and return their embeddings.

        Args:
            buffers: Dictionary mapping labels to image arrays

        Returns:
            Dictionary mapping labels to 512-d embeddings or None
        """
        if not buffers:
            return {}

        try:
            # Convert all buffers to PIL Images
            images = []
            labels = []
            for label, buffer in buffers.items():
                if buffer is not None and buffer.size > 0:
                    if isinstance(buffer, np.ndarray):
                        if buffer.dtype != np.uint8:
                            buffer = (buffer * 255).astype(np.uint8) if buffer.max() <= 1.0 else buffer.astype(np.uint8)
                        image = Image.fromarray(buffer)
                    else:
                        image = buffer
                    images.append(image)
                    labels.append(label)

            if not images:
                return {label: None for label in buffers.keys()}

            # Process batch
            inputs = self.processor(images=images, return_tensors="pt", padding=True).to(self.device)

            # Generate embeddings
            with torch.no_grad():
                image_features = self.model.get_image_features(**inputs)

            # Convert to numpy and normalize
            embeddings = image_features.cpu().numpy()
            embeddings = embeddings / np.linalg.norm(embeddings, axis=1, keepdims=True)

            # Map back to labels
            results = {}
            for i, label in enumerate(labels):
                results[label] = embeddings[i].astype(np.float32)

            # Add None for failed images
            for label in buffers.keys():
                if label not in results:
                    results[label] = None

            return results

        except Exception as e:
            print(f"Error in batch processing: {e}")
            # Fallback to individual processing
            return {label: self.infer(buffer, label) for label, buffer in buffers.items()}


__all__ = ["ImageEmbeddingInference"]


if __name__ == "__main__":
    """Demo usage of CLIP ImageEmbeddingInference."""
    print("\n" + "=" * 60)
    print("CLIP ViT-B/32 IMAGE EMBEDDING DEMO")
    print("=" * 60)

    # Initialize inference engine
    inference = ImageEmbeddingInference()

    print(f"\nModel: {inference.model_name}")
    print(f"Device: {inference.device}")
    print(f"Input size: {inference.input_size}")
    print(f"Embedding dimension: 512")

    # Single inference
    print("\n1. Single image inference...")
    dummy_image = (np.random.rand(224, 224, 3) * 255).astype(np.uint8)
    embedding = inference.infer(dummy_image, label="test_image_1")

    if embedding is not None:
        print(f"   Generated embedding shape: {embedding.shape}")
        print(f"   Embedding dtype: {embedding.dtype}")
        print(f"   Embedding norm: {np.linalg.norm(embedding):.4f} (should be ~1.0)")
        print(f"   Sample values: {embedding[:5]}")

    # Batch inference
    print("\n2. Batch inference...")
    buffers = {
        f"image_{i}": (np.random.rand(224, 224, 3) * 255).astype(np.uint8) for i in range(3)
    }

    embeddings = inference.infer_batch(buffers)

    print(f"   Processed {len(embeddings)} images")
    for label, emb in embeddings.items():
        if emb is not None:
            print(f"   {label}: shape={emb.shape}, norm={np.linalg.norm(emb):.4f}")

    # Similarity test
    print("\n3. Computing similarity...")
    if len(embeddings) >= 2:
        labels = list(embeddings.keys())
        emb1 = embeddings[labels[0]]
        emb2 = embeddings[labels[1]]

        if emb1 is not None and emb2 is not None:
            similarity = np.dot(emb1, emb2)
            print(f"   Similarity between {labels[0]} and {labels[1]}: {similarity:.4f}")

    print("\n" + "=" * 60)
    print("✅ Demo completed!")
    print("=" * 60)
    print("\nNOTE: Using production CLIP ViT-B/32 model from OpenAI.")
