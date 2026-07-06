"""Pytest fixtures: isolated SQLite database and authenticated client."""
import os

# Point the app at SQLite before any app module (and its engine) is imported.
os.environ.setdefault("DATABASE_URL", "sqlite:///./_test_app.db")

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.auth.security import hash_password
from app.database import Base, get_db
from app.main import app
from app.models.user import User, UserRole


@pytest.fixture()
def db_session():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    # Seed one user of each role.
    session.add_all(
        [
            User(username="admin", password_hash=hash_password("admin123"), role=UserRole.ADMIN),
            User(username="manager", password_hash=hash_password("manager123"), role=UserRole.MANAGER),
            User(username="employee", password_hash=hash_password("employee123"), role=UserRole.EMPLOYEE),
        ]
    )
    session.commit()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture()
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def _token(client: TestClient, username: str, password: str) -> str:
    resp = client.post("/api/login", json={"username": username, "password": password})
    assert resp.status_code == 200, resp.text
    return resp.json()["access_token"]


@pytest.fixture()
def admin_headers(client):
    return {"Authorization": f"Bearer {_token(client, 'admin', 'admin123')}"}


@pytest.fixture()
def employee_headers(client):
    return {"Authorization": f"Bearer {_token(client, 'employee', 'employee123')}"}
