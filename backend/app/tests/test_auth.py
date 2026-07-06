"""Authentication endpoint tests."""


def test_login_success(client):
    resp = client.post("/api/login", json={"username": "admin", "password": "admin123"})
    assert resp.status_code == 200
    assert resp.json()["token_type"] == "bearer"
    assert resp.json()["access_token"]


def test_login_wrong_password(client):
    resp = client.post("/api/login", json={"username": "admin", "password": "nope"})
    assert resp.status_code == 401


def test_me_requires_auth(client):
    assert client.get("/api/me").status_code == 401


def test_me_returns_current_user(client, admin_headers):
    resp = client.get("/api/me", headers=admin_headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["username"] == "admin"
    assert body["role"] == "admin"


def test_logout(client, admin_headers):
    resp = client.post("/api/logout", headers=admin_headers)
    assert resp.status_code == 200
