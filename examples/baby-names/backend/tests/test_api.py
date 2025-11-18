"""
Unit tests for backend API endpoints.
"""

import os
import sys
from unittest.mock import patch

import pytest

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import app


@pytest.fixture
def client():
    """Create test client."""
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_health_endpoint(client):
    """Test health endpoint returns 200."""
    with patch("app.db.health_check", return_value=True):
        response = client.get("/health")
        assert response.status_code == 200
        data = response.get_json()
        assert data["status"] == "healthy"
        assert data["database"] == "connected"


def test_health_endpoint_db_down(client):
    """Test health endpoint when database is down."""
    with patch("app.db.health_check", return_value=False):
        response = client.get("/health")
        assert response.status_code == 503
        data = response.get_json()
        assert data["status"] == "unhealthy"


def test_get_name_existing(client):
    """Test getting rank for an existing name."""
    mock_result = {"name": "Noah", "rank": 1, "count": 4382, "year": 2024}

    with patch("app.db.get_name_rank", return_value=mock_result):
        response = client.get("/api/v1/names/Noah")
        assert response.status_code == 200
        data = response.get_json()
        assert data["name"] == "Noah"
        assert data["rank"] == 1
        assert data["count"] == 4382


def test_get_name_not_found(client):
    """Test getting rank for a name that doesn't exist."""
    with patch("app.db.get_name_rank", return_value=None):
        response = client.get("/api/v1/names/UnknownName")
        assert response.status_code == 404
        data = response.get_json()
        assert "error" in data
        assert "not found" in data["error"].lower()


def test_get_name_empty(client):
    """Test getting rank with empty name."""
    response = client.get("/api/v1/names/ ")
    assert response.status_code == 400
    data = response.get_json()
    assert "error" in data


def test_get_all_names(client):
    """Test getting all names."""
    mock_results = [
        {"name": "Noah", "rank": 1, "count": 4382, "year": 2024},
        {"name": "Muhammad", "rank": 2, "count": 4258, "year": 2024},
    ]

    with patch("app.db.get_all_names", return_value=mock_results):
        response = client.get("/api/v1/names")
        assert response.status_code == 200
        data = response.get_json()
        assert data["count"] == 2
        assert len(data["names"]) == 2


def test_get_all_names_with_limit(client):
    """Test getting all names with custom limit."""
    with patch("app.db.get_all_names", return_value=[]) as mock_get:
        response = client.get("/api/v1/names?limit=50")
        assert response.status_code == 200
        mock_get.assert_called_once_with(limit=50)


def test_404_handler(client):
    """Test 404 error handler."""
    response = client.get("/nonexistent")
    assert response.status_code == 404
    data = response.get_json()
    assert "error" in data
