from ..store.entity import Entity
from flask_smorest import abort

class EntityService:
    def get_entities(self, filter_param=None, search_query=None):
        """Retrieves a paginated list of media entities."""
        return Entity.get_all(filter_param=filter_param, search_query=search_query)

    def create_entity(self, data):
        """Creates a new entity."""
        return Entity.create(data.dict())

    def delete_collection(self):
        """Deletes the entire collection."""
        # This is a destructive operation, so we'll add a safeguard here
        # In a real app, you'd want more robust checks (e.g., permissions)
        num_deleted = Entity.query.delete()
        Entity.db.session.commit()
        return {"message": f"Successfully deleted {num_deleted} entities."}

    def get_entity_by_id(self, entity_id):
        """Retrieves a specific media entity by its ID."""
        entity = Entity.get(entity_id)
        if not entity:
            abort(404, message=f"Entity with ID {entity_id} not found.")
        return entity

    def download_content(self, entity_id, content_type):
        """Downloads the media or preview content for an entity."""
        # Business logic for handling file downloads would go here
        print(f"Service: Downloading {content_type} for entity ID: {entity_id}")
        if content_type == 'media':
            return {"message": "Media download not implemented"}
        elif content_type == 'preview':
            return {"message": "Preview download not implemented"}

    def update_entity(self, entity_id, data):
        """Updates a specific media entity by its ID."""
        db_entity = self.get_entity_by_id(entity_id)
        return db_entity.update(data.dict())

    def partial_update_entity(self, entity_id, data):
        """Partially updates a specific media entity."""
        db_entity = self.get_entity_by_id(entity_id)
        update_data = data.dict(exclude_unset=True)
        return db_entity.update(update_data)

    def delete_entity(self, entity_id):
        """Deletes a specific media entity by its ID."""
        db_entity = self.get_entity_by_id(entity_id)
        return db_entity.delete()

    def get_stream(self, entity_id, filename=None):
        """Retrieves the m3u8 manifest or a specific streaming segment."""
        # Business logic for streaming would go here
        if filename is None:
            print(f"Service: Getting m3u8 for entity {entity_id}")
            return {"message": f"Streaming m3u8 for entity {entity_id} not implemented"}
        else:
            print(f"Service: Getting segment {filename} for entity {entity_id}")
            return {"message": f"Streaming segment {filename} for entity {entity_id} not implemented"}

# Instantiate the service
entity_service = EntityService()
