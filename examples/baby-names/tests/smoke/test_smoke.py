"""
Smoke tests for baby-names application.

These are lightweight tests to verify critical functionality after deployment.
Smoke tests should be fast and focus on the most important user paths.

Usage:
    pytest tests/smoke/test_smoke.py

Environment variables:
    BACKEND_URL: Backend service URL (default: http://localhost:5000)
    FRONTEND_URL: Frontend service URL (default: http://localhost:8080)
"""
import pytest
import requests
import os

BACKEND_URL = os.getenv('BACKEND_URL', 'http://localhost:5000')
FRONTEND_URL = os.getenv('FRONTEND_URL', 'http://localhost:8080')
TIMEOUT = 5  # seconds


class TestBackendSmoke:
    """Critical smoke tests for backend service."""

    def test_backend_is_up(self):
        """Verify backend service is responding."""
        response = requests.get(f'{BACKEND_URL}/health', timeout=TIMEOUT)
        assert response.status_code == 200

    def test_backend_database_connected(self):
        """Verify backend can connect to database."""
        response = requests.get(f'{BACKEND_URL}/health', timeout=TIMEOUT)
        data = response.json()
        assert data['database'] == 'connected'

    def test_backend_can_query_data(self):
        """Verify backend can query data from database."""
        # Noah should always be rank 1 in the 2024 dataset
        response = requests.get(f'{BACKEND_URL}/api/v1/names/Noah', timeout=TIMEOUT)
        assert response.status_code == 200
        data = response.json()
        assert data['name'] == 'Noah'
        assert data['rank'] == 1


class TestFrontendSmoke:
    """Critical smoke tests for frontend service."""

    def test_frontend_is_up(self):
        """Verify frontend service is responding."""
        response = requests.get(f'{FRONTEND_URL}/health', timeout=TIMEOUT)
        assert response.status_code == 200

    def test_frontend_page_loads(self):
        """Verify frontend page loads."""
        response = requests.get(FRONTEND_URL, timeout=TIMEOUT)
        assert response.status_code == 200
        assert b'Baby Names' in response.content

    def test_frontend_can_reach_backend(self):
        """Verify frontend can communicate with backend."""
        response = requests.get(f'{FRONTEND_URL}/?name=Noah', timeout=TIMEOUT)
        assert response.status_code == 200
        # Should show results, not an error
        assert b'Noah' in response.content
        assert b'#1' in response.content


class TestCriticalUserPath:
    """Test the most critical user journey."""

    def test_user_can_search_name(self):
        """Verify users can search for a baby name and get results."""
        # This is the primary use case - must work!
        response = requests.get(f'{FRONTEND_URL}/?name=Muhammad', timeout=TIMEOUT)
        assert response.status_code == 200

        content = response.content.decode('utf-8')
        assert 'Muhammad' in content
        # Muhammad should be rank 2
        assert '#2' in content or 'Rank: 2' in content


class TestDataIntegrity:
    """Verify critical data is present."""

    def test_top_name_is_noah(self):
        """Verify the #1 name in 2024 is Noah."""
        response = requests.get(f'{BACKEND_URL}/api/v1/names/Noah', timeout=TIMEOUT)
        assert response.status_code == 200
        data = response.json()
        assert data['rank'] == 1
        assert data['year'] == 2024

    def test_database_has_data(self):
        """Verify database contains baby names data."""
        response = requests.get(f'{BACKEND_URL}/api/v1/names?limit=10', timeout=TIMEOUT)
        assert response.status_code == 200
        data = response.json()
        assert data['count'] >= 10
        assert len(data['names']) == 10
