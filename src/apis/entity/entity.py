from flask.views import MethodView
from flask import request
from . import entity_bp
from ..schemas import Item, EntityUpdateSchema, EntityPatchSchema
from ...services.entity_service import entity_service

@entity_bp.route("/<int:entity_id>")
class Entity(MethodView):
    @entity_bp.response(200, Item)
    def get(self, entity_id):
        """
        Retrieves a specific media entity by its ID.
        Can also be used to download the media or preview content.
        """
        content_type = request.args.get('content')
        if content_type in ['media', 'preview']:
            return entity_service.download_content(entity_id, content_type)
        
        return entity_service.get_entity_by_id(entity_id)

    @entity_bp.arguments(EntityUpdateSchema, location="form")
    @entity_bp.response(201, Item)
    def put(self, update_data, entity_id):
        """Update a specific media entity by its ID."""
        return entity_service.update_entity(entity_id, update_data)

    @entity_bp.arguments(EntityPatchSchema, location="form")
    @entity_bp.response(200, Item)
    def patch(self, patch_data, entity_id):
        """Partially update a specific media entity, e.g., for soft delete/restore."""
        return entity_service.partial_update_entity(entity_id, patch_data)

    def delete(self, entity_id):
        """Delete a specific media entity by its ID."""
        return entity_service.delete_entity(entity_id)
