"""
Integration tests for the complete baby-names application.

These tests verify end-to-end functionality with all services running
(postgres, backend, frontend) via docker-compose.

Requirements:
- docker-compose must be running
- Services must be healthy before tests run
"""
import pytest
import requests
import time
import os

BACKEND_URL = os.getenv('BACKEND_URL', 'http://localhost:5000')
FRONTEND_URL = os.getenv('FRONTEND_URL', 'http://localhost:8080')
MAX_RETRIES = 30
RETRY_DELAY = 2


@pytest.fixture(scope='module', autouse=True)
def wait_for_services():
    """Wait for all services to be healthy before running tests."""
    print("\nWaiting for services to be ready...")

    # Wait for backend
    for i in range(MAX_RETRIES):
        try:
            response = requests.get(f'{BACKEND_URL}/health', timeout=2)
            if response.status_code == 200:
                print("Backend is ready")
                break
        except requests.exceptions.RequestException:
            if i == MAX_RETRIES - 1:
                pytest.fail("Backend service did not become healthy in time")
            time.sleep(RETRY_DELAY)

    # Wait for frontend
    for i in range(MAX_RETRIES):
        try:
            response = requests.get(f'{FRONTEND_URL}/health', timeout=2)
            if response.status_code == 200:
                print("Frontend is ready")
                break
        except requests.exceptions.RequestException:
            if i == MAX_RETRIES - 1:
                pytest.fail("Frontend service did not become healthy in time")
            time.sleep(RETRY_DELAY)

    yield


class TestBackendIntegration:
    """Integration tests for backend API with real database."""

    def test_backend_health(self):
        """Test backend health endpoint with database."""
        response = requests.get(f'{BACKEND_URL}/health')
        assert response.status_code == 200
        data = response.json()
        assert data['status'] == 'healthy'
        assert data['database'] == 'connected'

    def test_get_existing_name(self):
        """Test retrieving a name that exists in the database."""
        response = requests.get(f'{BACKEND_URL}/api/v1/names/Noah')
        assert response.status_code == 200
        data = response.json()
        assert data['name'] == 'Noah'
        assert data['rank'] == 1
        assert data['year'] == 2024
        assert 'count' in data

    def test_get_nonexistent_name(self):
        """Test retrieving a name that doesn't exist."""
        response = requests.get(f'{BACKEND_URL}/api/v1/names/ZzZzNonExistent')
        assert response.status_code == 404
        data = response.json()
        assert 'error' in data

    def test_get_all_names(self):
        """Test retrieving all names."""
        response = requests.get(f'{BACKEND_URL}/api/v1/names')
        assert response.status_code == 200
        data = response.json()
        assert 'names' in data
        assert 'count' in data
        assert len(data['names']) > 0
        # Verify names are ordered by rank
        ranks = [name['rank'] for name in data['names']]
        assert ranks == sorted(ranks)

    def test_get_names_with_limit(self):
        """Test retrieving names with custom limit."""
        limit = 10
        response = requests.get(f'{BACKEND_URL}/api/v1/names?limit={limit}')
        assert response.status_code == 200
        data = response.json()
        assert len(data['names']) == limit

    def test_case_insensitive_search(self):
        """Test that name search is case-insensitive."""
        # Test different case variations
        for name_variant in ['noah', 'NOAH', 'NoAh']:
            response = requests.get(f'{BACKEND_URL}/api/v1/names/{name_variant}')
            assert response.status_code == 200
            data = response.json()
            assert data['name'] == 'Noah'
            assert data['rank'] == 1


class TestFrontendIntegration:
    """Integration tests for frontend with real backend."""

    def test_frontend_health(self):
        """Test frontend health endpoint."""
        response = requests.get(f'{FRONTEND_URL}/health')
        assert response.status_code == 200
        data = response.json()
        assert data['status'] == 'healthy'

    def test_home_page_loads(self):
        """Test home page loads successfully."""
        response = requests.get(FRONTEND_URL)
        assert response.status_code == 200
        assert b'Baby Names Rank Finder' in response.content
        assert b'<form' in response.content

    def test_search_existing_name(self):
        """Test searching for an existing name via frontend."""
        response = requests.get(f'{FRONTEND_URL}/?name=Noah')
        assert response.status_code == 200
        assert b'Noah' in response.content
        assert b'#1' in response.content
        assert b'2024' in response.content

    def test_search_nonexistent_name(self):
        """Test searching for a non-existent name via frontend."""
        response = requests.get(f'{FRONTEND_URL}/?name=ZzZzNonExistent')
        assert response.status_code == 200
        assert b'not found' in response.content

    def test_empty_search(self):
        """Test frontend with empty search."""
        response = requests.get(f'{FRONTEND_URL}/?name=')
        assert response.status_code == 200
        assert b'Baby Names Rank Finder' in response.content


class TestEndToEnd:
    """End-to-end tests covering the complete user journey."""

    def test_complete_search_flow(self):
        """Test complete flow from frontend to database and back."""
        # User loads the page
        response = requests.get(FRONTEND_URL)
        assert response.status_code == 200

        # User searches for a name
        response = requests.get(f'{FRONTEND_URL}/?name=Muhammad')
        assert response.status_code == 200
        content = response.content.decode('utf-8')

        # Verify the response contains expected data
        assert 'Muhammad' in content
        assert '#2' in content or 'Rank: 2' in content
        assert '2024' in content

    def test_multiple_searches(self):
        """Test multiple consecutive searches."""
        test_names = ['Noah', 'Muhammad', 'Oliver']

        for name in test_names:
            response = requests.get(f'{FRONTEND_URL}/?name={name}')
            assert response.status_code == 200
            assert name.encode() in response.content

    def test_data_consistency(self):
        """Test that data is consistent between backend and frontend."""
        name = 'Noah'

        # Get data from backend directly
        backend_response = requests.get(f'{BACKEND_URL}/api/v1/names/{name}')
        backend_data = backend_response.json()

        # Get data from frontend (which calls backend)
        frontend_response = requests.get(f'{FRONTEND_URL}/?name={name}')
        frontend_content = frontend_response.content.decode('utf-8')

        # Verify frontend displays backend data correctly
        assert str(backend_data['rank']) in frontend_content
        assert str(backend_data['year']) in frontend_content
        assert backend_data['name'] in frontend_content


class TestDatabaseContent:
    """Tests to verify database content and integrity."""

    def test_top_names_present(self):
        """Verify top baby names from ONS 2024 are in database."""
        # Top 5 boys names from 2024 ONS data
        expected_names = ['Noah', 'Muhammad', 'Oliver', 'George', 'Arthur']

        for expected_name in expected_names:
            response = requests.get(f'{BACKEND_URL}/api/v1/names/{expected_name}')
            assert response.status_code == 200, f"{expected_name} should be in database"
            data = response.json()
            assert data['name'] == expected_name
            assert data['year'] == 2024

    def test_rank_ordering(self):
        """Verify names are correctly ranked."""
        response = requests.get(f'{BACKEND_URL}/api/v1/names?limit=100')
        assert response.status_code == 200
        data = response.json()

        # Verify ranks are sequential starting from 1
        for i, name_data in enumerate(data['names'], start=1):
            assert name_data['rank'] == i, f"Rank should be {i} but got {name_data['rank']}"
