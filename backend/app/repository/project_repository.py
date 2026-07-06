"""Data access for projects."""
from sqlalchemy.orm import Session

from app.models.project import Project


def count(db: Session) -> int:
    return db.query(Project).count()
