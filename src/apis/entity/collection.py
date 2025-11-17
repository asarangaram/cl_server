from flask.views import MethodView
from flask import request
from . import entity_bp
from ..schemas import Item, EntityCreateSchema
from ...services.entity_service import entity_service

@entity_bp.route("/")
class EntityCollection(MethodView):
    def get(self):
        """
        Retrieves a paginated list of media entities.
        Supports filtering via query parameters.
        """
        filter_param = request.args.get('filter')
        search_query = request.args.get('q')
        return entity_service.get_entities(filter_param, search_query)

    @entity_bp.arguments(EntityCreateSchema, location="form")
    @entity_bp.response(201, Item)
    def post(self, new_entity_data):
        """Created"""
        image_file = request.files.get('image')
        return entity_service.create_entity(new_entity_data, image_file)

    def delete(self):
        """Deletes the entire collection."""
        return entity_service.delete_collection()

