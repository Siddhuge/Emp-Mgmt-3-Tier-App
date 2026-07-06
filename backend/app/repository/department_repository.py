"""Data access for departments."""
from sqlalchemy.orm import Session

from app.models.department import Department
from app.schemas.department import DepartmentCreate


def list_all(db: Session) -> list[Department]:
    return db.query(Department).order_by(Department.name).all()


def get_by_id(db: Session, department_id: int) -> Department | None:
    return db.get(Department, department_id)


def get_by_name(db: Session, name: str) -> Department | None:
    return db.query(Department).filter(Department.name == name).first()


def create(db: Session, data: DepartmentCreate) -> Department:
    department = Department(name=data.name, manager=data.manager)
    db.add(department)
    db.commit()
    db.refresh(department)
    return department


def count(db: Session) -> int:
    return db.query(Department).count()
