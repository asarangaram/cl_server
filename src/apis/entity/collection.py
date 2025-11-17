from flask.views import MethodView
from flask import request
from . import entity_bp
from ..schemas import Item

@entity_bp.route("/")
class EntityCollection(MethodView):
    def get(self):
        """
        Retrieves a paginated list of media entities.
        Supports filtering via query parameters.
        """
        filter_param = request.args.get('filter')
        search_query = request.args.get('q')

        if filter_param == 'loopback':
            # Logic for loopback filter
            return {"message": "Loopback filter not implemented"}
        if search_query:
            # Logic for search
            return {"message": f"Search for '{search_query}' not implemented"}
            
        # Default behavior: return paginated list
        return {"message": "Not implemented"}

    @entity_bp.response(201, Item)
    def post(self):
        """Created"""
        return {"message": "Not implemented"}

    def delete(self):
        """Deletes the entire collection."""
        return {"message": "Collection reset not implemented"}

