

Create a Qdrant vector store for storing embeddings and metadata.
set up a docker container for qdrant with persistent storage.
keep the qdrant container running in the background.
use ../data/vector_store/qdrant as the persistent storage for qdrant.
add a read me, how to start the qdrant container.

The vector store client will be used by the inference service to store embeddings and metadata.


we shall have a wrapper service that handles vector_store.
