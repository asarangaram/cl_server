from flask import Flask
from flask_smorest import Api

from .apis.entity import entity_bp
from .apis.landing_bp import landing_bp
from .store.db import db

app = Flask(__name__)

app.config["API_TITLE"] = "CoLAN server"
app.config["API_VERSION"] = "v1"
app.config["OPENAPI_VERSION"] = "3.0.2"
app.config["OPENAPI_URL_PREFIX"] = "/"
app.config["OPENAPI_SWAGGER_UI_PATH"] = "/swagger-ui"
app.config["OPENAPI_SWAGGER_UI_URL"] = "https://cdn.jsdelivr.net/npm/swagger-ui-dist/"
app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///./test.db"

api = Api(app)
db.init_app(app)

api.register_blueprint(landing_bp)
api.register_blueprint(entity_bp)

if __name__ == "__main__":
    app.run(debug=True)
