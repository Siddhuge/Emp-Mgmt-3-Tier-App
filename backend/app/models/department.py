"""Department model."""
from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Department(Base):
    __tablename__ = "departments"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(150), unique=True, nullable=False)
    manager: Mapped[str | None] = mapped_column(String(150), nullable=True)

    employees: Mapped[list["Employee"]] = relationship(  # noqa: F821
        back_populates="department"
    )
