"""Employee endpoint tests (CRUD, search, role enforcement)."""


def _make_employee(client, headers, **overrides):
    payload = {
        "first_name": "Test",
        "last_name": "User",
        "email": "test.user@example.com",
        "designation": "Engineer",
        "salary": 90000,
        "is_active": True,
    }
    payload.update(overrides)
    return client.post("/api/employees", json=payload, headers=headers)


def test_create_and_list_employee(client, admin_headers):
    resp = _make_employee(client, admin_headers)
    assert resp.status_code == 201, resp.text
    created = resp.json()
    assert created["email"] == "test.user@example.com"

    listing = client.get("/api/employees", headers=admin_headers)
    assert listing.status_code == 200
    assert len(listing.json()) == 1


def test_duplicate_email_rejected(client, admin_headers):
    _make_employee(client, admin_headers)
    dup = _make_employee(client, admin_headers)
    assert dup.status_code == 409


def test_update_employee(client, admin_headers):
    emp = _make_employee(client, admin_headers).json()
    resp = client.put(
        f"/api/employees/{emp['id']}",
        json={"designation": "Lead Engineer", "salary": 130000},
        headers=admin_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["designation"] == "Lead Engineer"


def test_delete_employee(client, admin_headers):
    emp = _make_employee(client, admin_headers).json()
    resp = client.delete(f"/api/employees/{emp['id']}", headers=admin_headers)
    assert resp.status_code == 204
    assert client.get("/api/employees", headers=admin_headers).json() == []


def test_search_employee(client, admin_headers):
    _make_employee(client, admin_headers, email="alice@example.com", first_name="Alice")
    _make_employee(client, admin_headers, email="bob@example.com", first_name="Bob")
    resp = client.get("/api/employees", params={"search": "alice"}, headers=admin_headers)
    assert resp.status_code == 200
    results = resp.json()
    assert len(results) == 1
    assert results[0]["first_name"] == "Alice"


def test_employee_role_cannot_create(client, employee_headers):
    resp = _make_employee(client, employee_headers)
    assert resp.status_code == 403


def test_employee_role_cannot_delete(client, admin_headers, employee_headers):
    emp = _make_employee(client, admin_headers).json()
    resp = client.delete(f"/api/employees/{emp['id']}", headers=employee_headers)
    assert resp.status_code == 403
