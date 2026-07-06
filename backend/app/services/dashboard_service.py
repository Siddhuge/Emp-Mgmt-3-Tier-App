"""Dashboard aggregation logic."""
from sqlalchemy.orm import Session

from app.repository import (
    department_repository,
    employee_repository,
    project_repository,
)
from app.schemas.dashboard import DashboardStats


def get_stats(db: Session) -> DashboardStats:
    return DashboardStats(
        total_employees=employee_repository.count(db),
        departments=department_repository.count(db),
        projects=project_repository.count(db),
        active_employees=employee_repository.count_active(db),
    )
