"""Debug script to test SQLAlchemy-Continuum versioning."""
from server.database import SessionLocal, engine
from server.models import Base, Entity
from sqlalchemy.orm import configure_mappers
from sqlalchemy import inspect

# Configure mappers
configure_mappers()

# Create tables
Base.metadata.create_all(bind=engine)

# Check what tables exist
inspector = inspect(engine)
print("Tables in database:", inspector.get_table_names())

# Create a session
db = SessionLocal()

# Create an entity
import time
unique_md5 = f"test_{int(time.time())}"

entity = Entity(
    is_collection=False,
    label="Test Entity",
    description="Testing versioning",
    md5=unique_md5,
    file_path="/test/path.jpg"
)

db.add(entity)
db.commit()
db.refresh(entity)

print(f"\nCreated entity ID: {entity.id}")
print(f"Entity has 'versions' attribute: {hasattr(entity, 'versions')}")

if hasattr(entity, 'versions'):
    versions_list = entity.versions.all()
    print(f"Number of versions: {len(versions_list)}")
    for idx, version in enumerate(versions_list, 1):
        print(f"  Version {idx}: label={version.label}, md5={version.md5}")
else:
    print("No versions attribute found!")
    print(f"Entity attributes: {dir(entity)}")

# Try to access version class directly
try:
    from server.models import EntityVersion
    print(f"\nEntityVersion class exists: {EntityVersion}")
    versions_count = db.query(EntityVersion).count()
    print(f"Versions in database: {versions_count}")
except ImportError:
    print("\nEntityVersion class not found")

db.close()
