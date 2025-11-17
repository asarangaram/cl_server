import sqlalchemy as sa
from sqlalchemy_continuum import make_versioned
from .db import db

make_versioned(user_cls=None)

class Entity(db.Model):
    __tablename__ = 'entities'
    __versioned__ = {}

    id = sa.Column(sa.Integer, primary_key=True, index=True)
    is_collection = sa.Column(sa.Boolean, default=False)
    label = sa.Column(sa.String, nullable=True)
    description = sa.Column(sa.String, nullable=True)
    parent_id = sa.Column(sa.Integer, sa.ForeignKey('entities.id'), nullable=True)
    added_date = sa.Column(sa.DateTime, default=sa.func.now())
    updated_date = sa.Column(sa.DateTime, default=sa.func.now(), onupdate=sa.func.now())
    is_deleted = sa.Column(sa.Boolean, default=False)
    create_date = sa.Column(sa.DateTime, default=sa.func.now())
    file_size = sa.Column(sa.Integer, nullable=True)
    height = sa.Column(sa.Integer, nullable=True)
    width = sa.Column(sa.Integer, nullable=True)
    duration = sa.Column(sa.Float, nullable=True)
    mime_type = sa.Column(sa.String, nullable=True)
    type = sa.Column(sa.String, nullable=True)
    extension = sa.Column(sa.String, nullable=True)
    md5 = sa.Column(sa.String, nullable=True)

    @staticmethod
    def create(entity_data: dict):
        db_entity = Entity(**entity_data)
        db.session.add(db_entity)
        db.session.commit()
        db.session.refresh(db_entity)
        return db_entity

    @staticmethod
    def get(entity_id: int):
        return db.session.query(Entity).filter(Entity.id == entity_id).first()

    @staticmethod
    def get_all(filter_param: str = None, search_query: str = None):
        query = db.session.query(Entity)
        if filter_param == 'loopback':
            # Add loopback filter logic here
            pass
        if search_query:
            query = query.filter(Entity.label.ilike(f"%{search_query}%"))
        return query.all()

    def update(self, update_data: dict):
        for key, value in update_data.items():
            setattr(self, key, value)
        db.session.commit()
        db.session.refresh(self)
        return self

    def delete(self):
        db.session.delete(self)
        db.session.commit()
        return self

sa.orm.configure_mappers()
