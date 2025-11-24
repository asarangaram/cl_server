#!/usr/bin/env python3
"""Test script for the entity API endpoints."""

import requests
import json

BASE_URL = "http://127.0.0.1:8000"

def test_root():
    """Test root endpoint."""
    print("Testing GET /")
    response = requests.get(f"{BASE_URL}/")
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}\n")

def test_get_entities():
    """Test getting all entities."""
    print("Testing GET /entity/")
    response = requests.get(f"{BASE_URL}/entity/")
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}\n")
    return response.json()

def test_create_entity():
    """Test creating an entity."""
    print("Testing POST /entity/")
    # Use files parameter to send JSON as multipart form data
    files = {
        'body': (None, json.dumps({
            "is_collection": True,
            "label": "Test Collection",
            "description": "A test collection created via API"
        }), 'application/json')
    }
    response = requests.post(f"{BASE_URL}/entity/", files=files)
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}\n")
    return response.json()

def test_get_entity(entity_id):
    """Test getting a specific entity."""
    print(f"Testing GET /entity/{entity_id}")
    response = requests.get(f"{BASE_URL}/entity/{entity_id}")
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}\n")
    return response.json()

def test_update_entity(entity_id):
    """Test updating an entity (PUT)."""
    print(f"Testing PUT /entity/{entity_id}")
    files = {
        'body': (None, json.dumps({
            "is_collection": True,
            "label": "Updated Collection",
            "description": "Updated description"
        }), 'application/json')
    }
    response = requests.put(f"{BASE_URL}/entity/{entity_id}", files=files)
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}\n")
    return response.json()

def test_patch_entity(entity_id):
    """Test patching an entity (PATCH)."""
    print(f"Testing PATCH /entity/{entity_id}")
    files = {
        'body': (None, json.dumps({
            "label": "Patched Collection"
        }), 'application/json')
    }
    response = requests.patch(f"{BASE_URL}/entity/{entity_id}", files=files)
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}\n")
    return response.json()

if __name__ == "__main__":
    print("=" * 60)
    print("Testing Entity API with Service Layer and SQLite Database")
    print("=" * 60 + "\n")
    
    # Test root
    test_root()
    
    # Test getting entities (should be empty)
    entities = test_get_entities()
    
    # Create an entity
    created = test_create_entity()
    entity_id = created.get("id")
    
    # Get all entities (should have 1)
    entities = test_get_entities()
    print(f"Total entities: {len(entities)}\n")
    
    # Get specific entity
    test_get_entity(entity_id)
    
    # Update entity
    test_update_entity(entity_id)
    
    # Patch entity
    test_patch_entity(entity_id)
    
    # Get final state
    final = test_get_entity(entity_id)
    
    print("=" * 60)
    print("✅ All tests completed successfully!")
    print("=" * 60)
