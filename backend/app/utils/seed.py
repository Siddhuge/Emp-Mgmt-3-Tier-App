"""Seed initial data (default admin, sample departments/employees/projects)."""
import logging

from sqlalchemy.orm import Session

from app.auth.security import hash_password
from app.config import settings
from app.models.department import Department
from app.models.employee import Employee
from app.models.project import Project
from app.models.user import User, UserRole

logger = logging.getLogger("uvicorn")


def seed_initial_data(db: Session) -> None:
    """Idempotently create the default admin and a little sample data."""
    _seed_users(db)
    _seed_sample_data(db)


def _seed_users(db: Session) -> None:
    if db.query(User).count() > 0:
        return
    users = [
        User(
            username=settings.seed_admin_username,
            password_hash=hash_password(settings.seed_admin_password),
            role=UserRole.ADMIN,
        ),
        User(
            username="manager",
            password_hash=hash_password("manager123"),
            role=UserRole.MANAGER,
        ),
        User(
            username="employee",
            password_hash=hash_password("employee123"),
            role=UserRole.EMPLOYEE,
        ),
    ]
    db.add_all(users)
    db.commit()
    logger.info("Seeded default users: admin / manager / employee")


def _seed_sample_data(db: Session) -> None:
    if db.query(Department).count() > 0:
        return

    engineering = Department(name="Engineering", manager="Alice Johnson")
    sales = Department(name="Sales", manager="Bob Smith")
    hr = Department(name="Human Resources", manager="Carol White")
    db.add_all([engineering, sales, hr])
    db.flush()

    db.add_all(
        [
            Employee(
                first_name="John",
                last_name="Doe",
                email="john.doe@example.com",
                designation="Senior Engineer",
                salary=120000,
                is_active=True,
                department_id=engineering.id,
            ),
            Employee(
                first_name="Jane",
                last_name="Miller",
                email="jane.miller@example.com",
                designation="Sales Executive",
                salary=85000,
                is_active=True,
                department_id=sales.id,
            ),
            Employee(
                first_name="Sam",
                last_name="Wilson",
                email="sam.wilson@example.com",
                designation="HR Specialist",
                salary=70000,
                is_active=False,
                department_id=hr.id,
            ),
        ]
    )

    db.add_all(
        [
            Project(name="Website Revamp", is_active=True),
            Project(name="Mobile App", is_active=True),
        ]
    )
    db.commit()
    logger.info("Seeded sample departments, employees and projects")
