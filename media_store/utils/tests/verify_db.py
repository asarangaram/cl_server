#!/usr/bin/env python3
"""Simple test to verify database persistence."""

import sqlite3
import sys

# Connect to the database
db_path = "data/entities.db"

try:
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Check if entities table exists
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='entities';")
    table_exists = cursor.fetchone()
    
    if table_exists:
        print("✅ Database table 'entities' exists")
        
        # Get table schema
        cursor.execute("PRAGMA table_info(entities);")
        columns = cursor.fetchall()
        print(f"\n📋 Table schema ({len(columns)} columns):")
        for col in columns:
            print(f"  - {col[1]} ({col[2]})")
        
        # Count entities
        cursor.execute("SELECT COUNT(*) FROM entities;")
        count = cursor.fetchone()[0]
        print(f"\n📊 Total entities in database: {count}")
        
        # Show all entities if any exist
        if count > 0:
            cursor.execute("SELECT * FROM entities;")
            entities = cursor.fetchall()
            print(f"\n📦 Entities:")
            for entity in entities:
                print(f"  {entity}")
    else:
        print("❌ Database table 'entities' does not exist")
        sys.exit(1)
    
    conn.close()
    print("\n✅ Database verification successful!")
    
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)
