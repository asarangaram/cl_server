from __future__ import annotations

from datetime import datetime
from typing import Dict, List, Optional

from sqlalchemy.orm import Session

from schemas import BodyCreateEntity, BodyPatchEntity, BodyUpdateEntity, Item

from ..models import Entity


class EntityService:
    """Service layer for entity operations."""
    
    def __init__(self, db: Session):
        """
        Initialize the entity service.
        
        Args:
            db: SQLAlchemy database session
        """
        self.db = db
    
    @staticmethod
    def _now_iso() -> str:
        """Return current UTC time in ISO-8601 format."""
        return datetime.utcnow().isoformat() + "Z"
    
    @staticmethod
    def _fake_file_metadata(file_bytes: Optional[bytes]) -> Dict[str, int]:
        """Return dummy file metadata – size, dummy dimensions."""
        if not file_bytes:
            return {}
        return {"size": len(file_bytes), "height": 100, "width": 100}
    
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
        image: Optional[bytes] = None
    ) -> Item:
        """
        Create a new entity.
        
        Args:
            body: Entity creation data
            image: Optional image file bytes
            
        Returns:
            Created Item instance
        """
        now = self._now_iso()
        file_meta = self._fake_file_metadata(image)
        
        entity = Entity(
            is_collection=body.is_collection,
            label=body.label,
            description=body.description,
            parent_id=body.parent_id,
            added_date=now,
            updated_date=now,
            create_date=now,
            file_size=file_meta.get("size"),
            height=file_meta.get("height"),
            width=file_meta.get("width"),
            is_deleted=False,
        )
        
        self.db.add(entity)
        self.db.commit()
        self.db.refresh(entity)
        
        return self._entity_to_item(entity)
    
    def update_entity(self, entity_id: int, body: BodyUpdateEntity) -> Optional[Item]:
        """
        Fully update an existing entity (PUT).
        
        Args:
            entity_id: Entity ID
            body: Entity update data
            
        Returns:
            Updated Item instance or None if not found
        """
        entity = self.db.query(Entity).filter(Entity.id == entity_id).first()
        if not entity:
            return None
        
        now = self._now_iso()
        entity.is_collection = body.is_collection
        entity.label = body.label
        entity.description = body.description
        entity.parent_id = body.parent_id
        entity.updated_date = now
        
        self.db.commit()
        self.db.refresh(entity)
        
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
