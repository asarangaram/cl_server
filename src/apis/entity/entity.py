from flask.views import MethodView
from flask import request
from . import entity_bp
from ..schemas import Item

@entity_bp.route("/<int:entity_id>")
class Entity(MethodView):
    @entity_bp.response(200, Item)
    def get(self, entity_id):
        """
        Retrieves a specific media entity by its ID.
        Can also be used to download the media or preview content.
        """
        content_type = request.args.get('content')
        if content_type == 'media':
            # Logic to download media file
            return {"message": "Media download not implemented"}
        elif content_type == 'preview':
            # Logic to download preview file
            return {"message": "Preview download not implemented"}
        
        # Default behavior: return entity metadata
        return {"message": "Not implemented"}

    @entity_bp.response(201, Item)
    def put(self, entity_id):
        """Update a specific media entity by its ID."""
        return {"message": "Not implemented"}

    @entity_bp.response(200, Item)
    def patch(self, entity_id):
        """Partially update a specific media entity, e.g., for soft delete/restore."""
        is_deleted = request.form.get('is_deleted')
        if is_deleted is not None:
            # Logic to update the is_deleted status
            return {"message": f"Entity {entity_id} is_deleted status set to {is_deleted}"}
        return {"message": "No update performed"}

    def delete(self, entity_id):
        """Delete a specific media entity by its ID."""
        return {"message": "Not implemented"}
