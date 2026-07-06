"""FastAPI application entrypoint."""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import Base, SessionLocal, engine
from app.routes import auth, dashboard, departments, employees
from app.utils.seed import seed_initial_data

logger = logging.getLogger("uvicorn")


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Phase 1: create tables on startup for a frictionless local run.
    # Alembic migrations are the source of truth for schema changes.
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        seed_initial_data(db)
    except Exception:  # pragma: no cover - defensive startup guard
        logger.exception("Failed to seed initial data")
    finally:
        db.close()
    yield


app = FastAPI(
    title="Employee Management API",
    version="1.0.0",
    description="Phase 1 - Employee Management System backend",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(employees.router)
app.include_router(departments.router)
app.include_router(dashboard.router)


@app.get("/health", tags=["health"])
def health_check() -> dict[str, str]:
    return {"status": "ok"}
