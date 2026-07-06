"""Data access for employees."""
from sqlalchemy import or_
from sqlalchemy.orm import Session, joinedload

from app.models.employee import Employee


def list_all(db: Session, search: str | None = None) -> list[Employee]:
    query = db.query(Employee).options(joinedload(Employee.department))
    if search:
        term = f"%{search.lower()}%"
        query = query.filter(
            or_(
                Employee.first_name.ilike(term),
                Employee.last_name.ilike(term),
                Employee.email.ilike(term),
                Employee.designation.ilike(term),
            )
        )
    return query.order_by(Employee.id).all()


def get_by_id(db: Session, employee_id: int) -> Employee | None:
    return (
        db.query(Employee)
        .options(joinedload(Employee.department))
        .filter(Employee.id == employee_id)
        .first()
    )


def get_by_email(db: Session, email: str) -> Employee | None:
    return db.query(Employee).filter(Employee.email == email).first()


def create(db: Session, employee: Employee) -> Employee:
    db.add(employee)
    db.commit()
    db.refresh(employee)
    return employee


def save(db: Session, employee: Employee) -> Employee:
    db.commit()
    db.refresh(employee)
    return employee


def delete(db: Session, employee: Employee) -> None:
    db.delete(employee)
    db.commit()


def count(db: Session) -> int:
    return db.query(Employee).count()


def count_active(db: Session) -> int:
    return db.query(Employee).filter(Employee.is_active.is_(True)).count()
