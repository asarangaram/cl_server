"""Example usage of the Qdrant vector store client."""

import numpy as np

from vector_store_client import VectorStoreClient


def main():
    """Demonstrate vector store client usage."""
    # Initialize client
    client = VectorStoreClient(host="localhost", port=6333)

    print("🔌 Connected to Qdrant")

    # Example 1: Store image embedding
    print("\n📝 Storing image embedding...")
    image_embedding = np.random.randn(512).astype(np.float32).tolist()

    client.store_image_embedding(
        job_id="job-123",
        media_store_id="media-456",
        embedding=image_embedding,
        metadata={"created_at": 1700000000000, "user_id": "user-789"},
    )

    # Example 2: Store face embeddings
    print("📝 Storing face embeddings...")
    for i in range(3):
        face_embedding = np.random.randn(512).astype(np.float32).tolist()

        client.store_face_embedding(
            job_id="job-124",
            media_store_id="media-457",
            face_index=i,
            embedding=face_embedding,
            bbox={"x": 100.0 + i * 50, "y": 150.0, "width": 80.0, "height": 90.0},
            metadata={"confidence": 0.95 + i * 0.01},
        )

    # Example 3: Search for similar images
    print("\n🔍 Searching for similar images...")
    query_vector = np.random.randn(512).astype(np.float32).tolist()

    results = client.search_similar_images(query_vector=query_vector, limit=5, score_threshold=0.5)

    print(f"Found {len(results)} similar images:")
    for result in results:
        print(f"  - ID: {result['id']}, Score: {result['score']:.4f}")
        print(f"    Media: {result['payload']['media_store_id']}")

    # Example 4: Search for similar faces
    print("\n🔍 Searching for similar faces...")
    results = client.search_similar_faces(query_vector=query_vector, limit=5)

    print(f"Found {len(results)} similar faces:")
    for result in results:
        print(f"  - ID: {result['id']}, Score: {result['score']:.4f}")
        print(f"    Face index: {result['payload']['face_index']}")

    # Example 5: Get collection info
    print("\n📊 Collection info:")
    for collection in ["image_embeddings", "face_embeddings"]:
        try:
            info = client.get_collection_info(collection)
            print(f"  {collection}:")
            print(f"    Points: {info['points_count']}")
            print(f"    Status: {info['status']}")
        except Exception as e:
            print(f"  {collection}: Not found or error - {e}")

    # Example 6: Delete vectors
    print("\n🗑️  Deleting vectors for job-123...")
    deleted = client.delete_by_job_id("job-123")
    print(f"Deleted {deleted} vectors")

    print("\n✅ Done!")


if __name__ == "__main__":
    main()
