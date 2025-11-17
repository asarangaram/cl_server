from flask.views import MethodView

from . import entity_bp


@entity_bp.route("/uploadform")
class EntityUploadForm(MethodView):
    def get(self):
        """Renders the media upload form."""
        return {"message": "Not implemented"}
