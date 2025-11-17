from flask.views import MethodView
from . import entity_bp
from ...services.entity_service import entity_service

@entity_bp.route("/<int:entity_id>/stream")
@entity_bp.route("/<int:entity_id>/stream/<string:filename>")
class EntityStream(MethodView):
    def get(self, entity_id, filename=None):
        """
        Retrieves the m3u8 manifest or a specific streaming segment.
        """
        return entity_service.get_stream(entity_id, filename)