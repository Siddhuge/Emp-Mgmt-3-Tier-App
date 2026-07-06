"""Department and dashboard endpoint tests."""


def test_create_and_list_department(client, admin_headers):
    resp = client.post(
        "/api/departments",
        json={"name": "Engineering", "manager": "Alice"},
        headers=admin_headers,
    )
    assert resp.status_code == 201, resp.text
    listing = client.get("/api/departments", headers=admin_headers)
    assert listing.status_code == 200
    assert listing.json()[0]["name"] == "Engineering"


def test_duplicate_department_rejected(client, admin_headers):
    client.post("/api/departments", json={"name": "Sales"}, headers=admin_headers)
    dup = client.post("/api/departments", json={"name": "Sales"}, headers=admin_headers)
    assert dup.status_code == 409


def test_dashboard_counts(client, admin_headers):
    client.post("/api/departments", json={"name": "Eng"}, headers=admin_headers)
    client.post(
        "/api/employees",
        json={
            "first_name": "A",
            "last_name": "B",
            "email": "a.b@example.com",
            "is_active": True,
        },
        headers=admin_headers,
    )
    client.post(
        "/api/employees",
        json={
            "first_name": "C",
            "last_name": "D",
            "email": "c.d@example.com",
            "is_active": False,
        },
        headers=admin_headers,
    )
    resp = client.get("/api/dashboard", headers=admin_headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["total_employees"] == 2
    assert body["active_employees"] == 1
    assert body["departments"] == 1
    assert body["projects"] == 0
