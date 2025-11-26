#!/bin/bash

# Qdrant Vector Store - Stop Script

set -e

echo "🛑 Stopping Qdrant Vector Store..."

# Navigate to vector_store directory
cd "$(dirname "$0")"

# Check if container is running
if ! docker ps | grep -q qdrant-vector-store; then
    echo "ℹ️  Qdrant container is not running"
    exit 0
fi

# Stop Qdrant container
echo "📦 Stopping Qdrant container..."
docker-compose stop

echo "✅ Qdrant stopped successfully"
echo ""
echo "To start again: ./start.sh"
echo "To remove container: docker-compose down"
echo "To view status: docker-compose ps"
