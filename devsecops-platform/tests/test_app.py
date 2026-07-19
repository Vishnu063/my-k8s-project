import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "app"))
from app import app  # noqa: E402


def test_index_returns_200():
    client = app.test_client()
    response = client.get("/")
    assert response.status_code == 200
    assert response.get_json()["message"] == "Hello from the DevSecOps platform"


def test_healthz_returns_200():
    client = app.test_client()
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.get_json()["status"] == "ok"
