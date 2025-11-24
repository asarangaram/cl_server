from __future__ import annotations

import tempfile
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from clmediakit import CLMetaData
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from schemas import BodyCreateEntity, BodyPatchEntity, BodyUpdateEntity, Item

from ..models import Entity
from .file_storage import FileStorageService


class DuplicateFileError(Exception):
    """Raised when attempting to upload a file with duplicate MD5."""
    pass


class EntityService:
    """Service layer for entity operations."""
    
    def __init__(self, db: Session):
        """
        Initialize the entity service.
        
        Args:
            db: SQLAlchemy database session
        """
        self.db = db
        self.file_storage = FileStorageService()
    
    @staticmethod
    def _now_iso() -> str:
        """Return current UTC time in ISO-8601 format."""
        return datetime.utcnow().isoformat() + "Z"
    
    def _extract_metadata(self, file_bytes: bytes, filename: str = "file") -> Dict:
        """
        Extract metadata from file using CLMetaData.
        
        Args:
            file_bytes: File content as bytes
            filename: Original filename for extension detection
            
        Returns:
            Dictionary containing file metadata
        """
        # Create temporary file for CLMetaData processing
        with tempfile.NamedTemporaryFile(delete=False, suffix=Path(filename).suffix) as tmp_file:
            tmp_file.write(file_bytes)
            tmp_path = tmp_file.name
        
        try:
            # Extract metadata using CLMetaData
            cl_metadata = CLMetaData.from_media(tmp_path)
            metadata = cl_metadata.to_dict()
            return metadata
        finally:
            # Clean up temporary file
            Path(tmp_path).unlink(missing_ok=True)
    
    def _check_duplicate_md5(self, md5: str, exclude_entity_id: Optional[int] = None) -> Optional[Entity]:
        """
        Check if an entity with the given MD5 already exists.
        
        Args:
            md5: MD5 hash to check
            exclude_entity_id: Optional entity ID to exclude from check (for updates)
            
        Returns:
            Entity if duplicate found, None otherwise
        """
        query = self.db.query(Entity).filter(Entity.md5 == md5)
        
        if exclude_entity_id is not None:
            query = query.filter(Entity.id != exclude_entity_id)
        
        return query.first()
    
    @staticmethod
    def _entity_to_item(entity: Entity) -> Item:
        """
        Convert SQLAlchemy Entity model to Pydantic Item schema.
        
        Args:
            entity: SQLAlchemy Entity instance
            
        Returns:
            Pydantic Item instance
        """
        return Item(
            id=entity.id,
            is_collection=entity.is_collection,
            label=entity.label,
            description=entity.description,
            parent_id=entity.parent_id,
            added_date=entity.added_date,
            updated_date=entity.updated_date,
            create_date=entity.create_date,
            file_size=entity.file_size,
            height=entity.height,
            width=entity.width,
            duration=entity.duration,
            mime_type=entity.mime_type,
            type=entity.type,
            extension=entity.extension,
            md5=entity.md5,
            is_deleted=entity.is_deleted,
        )
    
    def get_entities(
        self, 
        filter_param: Optional[str] = None, 
        search_query: Optional[str] = None
    ) -> List[Item]:
        """
        Retrieve all entities with optional filtering.
        
        Args:
            filter_param: Optional filter string (not implemented yet)
            search_query: Optional search query (not implemented yet)
            
        Returns:
            List of Item instances
        """
        query = self.db.query(Entity)
        
        # TODO: Implement filtering and search logic
        # For now, return all entities
        
        entities = query.all()
        return [self._entity_to_item(entity) for entity in entities]
    
    def get_entity_by_id(self, entity_id: int) -> Optional[Item]:
        """
        Retrieve a single entity by ID.
        
        Args:
            entity_id: Entity ID
            
        Returns:
            Item instance or None if not found
        """
        entity = self.db.query(Entity).filter(Entity.id == entity_id).first()
        if entity:
            return self._entity_to_item(entity)
        return None
    
    def create_entity(
        self, 
        body: BodyCreateEntity, 
        image: Optional[bytes] = None,
        filename: str = "file"
    ) -> Item:
        """
        Create a new entity.
        
        Args:
            body: Entity creation data
            image: Optional image file bytes
            filename: Original filename
            
        Returns:
            Created Item instance
            
        Raises:
            DuplicateFileError: If file with same MD5 already exists
        """
        now = self._now_iso()
        file_meta = {}
        file_path = None
        
        # Extract metadata and save file if provided
        if image:
            # Extract metadata using CLMetaData
            file_meta = self._extract_metadata(image, filename)
            
            # Check for duplicate MD5
            if file_meta.get("md5"):
                duplicate = self._check_duplicate_md5(file_meta["md5"])
                if duplicate:
                    raise DuplicateFileError(
                        f"File with MD5 {file_meta['md5']} already exists (entity ID: {duplicate.id})"
                    )
            
            # Save file to storage
            file_path = self.file_storage.save_file(image, file_meta, filename)
        
        entity = Entity(
            is_collection=body.is_collection,
            label=body.label,
            description=body.description,
            parent_id=body.parent_id,
            added_date=now,
            updated_date=now,
            create_date=now,
            file_size=file_meta.get("FileSize"),
            height=file_meta.get("ImageHeight"),
            width=file_meta.get("ImageWidth"),
            duration=file_meta.get("Duration"),
            mime_type=file_meta.get("MIMEType"),
            type=file_meta.get("type"),
            extension=file_meta.get("extension"),
            md5=file_meta.get("md5"),
            file_path=file_path,
            is_deleted=False,
        )
        
        try:
            self.db.add(entity)
            self.db.commit()
            self.db.refresh(entity)
        except IntegrityError as e:
            self.db.rollback()
            # Clean up file if database insert failed
            if file_path:
                self.file_storage.delete_file(file_path)
            raise DuplicateFileError(f"Duplicate MD5 detected: {file_meta.get('md5')}")
        
        return self._entity_to_item(entity)
    
    def update_entity(
        self, 
        entity_id: int, 
        body: BodyUpdateEntity,
        image: bytes,
        filename: str = "file"
    ) -> Optional[Item]:
        """
        Fully update an existing entity (PUT) - requires file upload.
        
        Args:
            entity_id: Entity ID
            body: Entity update data
            image: Image file bytes (mandatory for PUT)
            filename: Original filename
            
        Returns:
            Updated Item instance or None if not found
            
        Raises:
            DuplicateFileError: If file with same MD5 already exists
        """
        entity = self.db.query(Entity).filter(Entity.id == entity_id).first()
        if not entity:
            return None
        
        # Extract metadata from new file
        file_meta = self._extract_metadata(image, filename)
        
        # Check for duplicate MD5 (excluding current entity)
        if file_meta.get("md5"):
            duplicate = self._check_duplicate_md5(file_meta["md5"], exclude_entity_id=entity_id)
            if duplicate:
                raise DuplicateFileError(
                    f"File with MD5 {file_meta['md5']} already exists (entity ID: {duplicate.id})"
                )
        
        # Delete old file if exists
        old_file_path = entity.file_path
        if old_file_path:
            self.file_storage.delete_file(old_file_path)
        
        # Save new file
        file_path = self.file_storage.save_file(image, file_meta, filename)
        
        # Update entity with new metadata and client-provided fields
        now = self._now_iso()
        entity.is_collection = body.is_collection
        entity.label = body.label
        entity.description = body.description
        entity.parent_id = body.parent_id
        entity.updated_date = now
        
        # Update file metadata
        entity.file_size = file_meta.get("FileSize")
        entity.height = file_meta.get("ImageHeight")
        entity.width = file_meta.get("ImageWidth")
        entity.duration = file_meta.get("Duration")
        entity.mime_type = file_meta.get("MIMEType")
        entity.type = file_meta.get("type")
        entity.extension = file_meta.get("extension")
        entity.md5 = file_meta.get("md5")
        entity.file_path = file_path
        
        try:
            self.db.commit()
            self.db.refresh(entity)
        except IntegrityError:
            self.db.rollback()
            # Clean up new file if database update failed
            if file_path:
                self.file_storage.delete_file(file_path)
            raise DuplicateFileError(f"Duplicate MD5 detected: {file_meta.get('md5')}")
        
        return self._entity_to_item(entity)
    
    def patch_entity(self, entity_id: int, body: BodyPatchEntity) -> Optional[Item]:
        """
        Partially update an existing entity (PATCH).
        
        Args:
            entity_id: Entity ID
            body: Entity patch data (only provided fields will be updated)
            
        Returns:
            Updated Item instance or None if not found
        """
        entity = self.db.query(Entity).filter(Entity.id == entity_id).first()
        if not entity:
            return None
        
        # Update only provided fields
        for field, value in body.dict(exclude_unset=True).items():
            setattr(entity, field, value)
        
        entity.updated_date = self._now_iso()
        
        self.db.commit()
        self.db.refresh(entity)
        
        return self._entity_to_item(entity)
    
    def delete_entity(self, entity_id: int) -> Optional[Item]:
        """
        Soft delete an entity (set is_deleted=True).
        
        Args:
            entity_id: Entity ID
            
        Returns:
            Deleted Item instance or None if not found
        """
        entity = self.db.query(Entity).filter(Entity.id == entity_id).first()
        if not entity:
            return None
        
        entity.is_deleted = True
        entity.updated_date = self._now_iso()
        
        self.db.commit()
        self.db.refresh(entity)
        
        return self._entity_to_item(entity)
    
    def delete_all_entities(self) -> None:
        """Delete all entities from the database."""
        self.db.query(Entity).delete()
        self.db.commit()
