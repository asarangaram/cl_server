from fastapi import FastAPI
from fastapi import FastAPI
from src import models, database, routes, config, service, schemas

# Create tables (for development/testing without migrations)
# In production, use Alembic
models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="User Auth Service", version="0.1.0")

app.include_router(routes.router)

@app.on_event("startup")
def startup_event():
    # Create default admin if not exists
    db = database.SessionLocal()
    try:
        user_service = service.UserService(db)
        admin = user_service.get_user_by_username(config.ADMIN_USERNAME)
        if not admin:
            print(f"Creating default admin user: {config.ADMIN_USERNAME}")
            admin_create = schemas.UserCreate(
                username=config.ADMIN_USERNAME,
                password=config.ADMIN_PASSWORD,
                is_admin=True,
                permissions=["*"] # Grant all permissions
            )
            user_service.create_user(admin_create)
    finally:
        db.close()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
