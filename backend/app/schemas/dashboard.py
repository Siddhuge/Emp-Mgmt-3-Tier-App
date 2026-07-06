"""Dashboard schemas."""
from pydantic import BaseModel


class DashboardStats(BaseModel):
    total_employees: int
    departments: int
    projects: int
    active_employees: int
