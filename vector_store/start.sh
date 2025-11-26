#!/bin/bash

# Qdrant Vector Store - Start Script

set -e

echo "🚀 Starting Qdrant Vector Store..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running. Please start Docker first."
    exit 1
fi

# Navigate to vector_store directory
cd "$(dirname "$0")"

# Create data directory if it doesn't exist
mkdir -p ../data/vector_store/qdrant

# Start Qdrant container
echo "📦 Starting Qdrant container..."
docker-compose up -d

# Wait for Qdrant to be healthy
echo "⏳ Waiting for Qdrant to be ready..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if curl -s http://localhost:6333/health > /dev/null 2>&1; then
        echo "✅ Qdrant is ready!"
        echo ""
        echo "📊 Qdrant Dashboard: http://localhost:6333/dashboard"
        echo "🔌 REST API: http://localhost:6333"
        echo "🔌 gRPC API: localhost:6334"
        echo ""
        echo "💾 Data stored in: ../data/vector_store/qdrant"
        echo ""
        echo "To stop: docker-compose stop"
        echo "To view logs: docker-compose logs -f qdrant"
        exit 0
    fi
    
    attempt=$((attempt + 1))
    sleep 2
done

echo "❌ Qdrant failed to start within 60 seconds"
echo "Check logs with: docker-compose logs qdrant"
exit 1
