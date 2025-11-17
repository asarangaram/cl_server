from flask.views import MethodView
from flask_smorest import Blueprint

from .schemas import LandingPageResult

landing_bp = Blueprint("landing_bp", __name__, url_prefix="/")


@landing_bp.route("/")
class Landing(MethodView):
    @landing_bp.response(200, LandingPageResult)
    def get(self):
        """OK"""
        return {"name": "CoLAN server", "info": "v1", "id": 1}
