"""
Unit tests for frontend application.
"""

import os
import sys
from unittest.mock import Mock, patch

import pytest
import requests

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import app


@pytest.fixture
def client():
    """Create test client."""
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_home_page_loads(client):
    """Test home page loads successfully."""
    response = client.get("/")
    assert response.status_code == 200
    assert b"Baby Names Rank Finder" in response.data


def test_health_endpoint(client):
    """Test health endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "healthy"


def test_search_success(client):
    """Test successful name search."""
    mock_response = Mock()
    mock_response.status_code = 200
    mock_response.json.return_value = {"name": "Noah", "rank": 1, "count": 4382, "year": 2024}

    with patch("app.requests.get", return_value=mock_response):
        response = client.get("/?name=Noah")
        assert response.status_code == 200
        assert b"Noah" in response.data
        assert b"#1" in response.data


def test_search_not_found(client):
    """Test search for non-existent name."""
    mock_response = Mock()
    mock_response.status_code = 404

    with patch("app.requests.get", return_value=mock_response):
        response = client.get("/?name=UnknownName")
        assert response.status_code == 200
        assert b"not found" in response.data


def test_search_backend_error(client):
    """Test search when backend returns error."""
    mock_response = Mock()
    mock_response.status_code = 500

    with patch("app.requests.get", return_value=mock_response):
        response = client.get("/?name=TestName")
        assert response.status_code == 200
        assert b"Error" in response.data


def test_search_backend_unavailable(client):
    """Test search when backend is unavailable."""
    with patch("app.requests.get", side_effect=requests.exceptions.ConnectionError("Connection refused")):
        response = client.get("/?name=TestName")
        assert response.status_code == 200
        assert b"Unable to connect" in response.data


def test_empty_search(client):
    """Test search with empty name."""
    response = client.get("/?name=")
    assert response.status_code == 200
    # Should show form but no results or errors
    assert b"Baby Names Rank Finder" in response.data
