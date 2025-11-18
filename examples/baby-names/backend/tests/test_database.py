"""
Unit tests for database layer.
"""

import os
import sys
from unittest.mock import MagicMock, patch

import pytest

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


@pytest.fixture
def mock_db():
    """Create mock database instance."""
    with patch("database.psycopg2.pool.SimpleConnectionPool"):
        from database import Database

        db = Database()
        yield db


def test_get_name_rank_found(mock_db):
    """Test getting rank for existing name."""
    # Mock connection and cursor
    mock_cursor = MagicMock()
    mock_cursor.fetchone.return_value = {"name": "Noah", "rank": 1, "count": 4382, "year": 2024}

    mock_conn = MagicMock()
    mock_conn.cursor.return_value = mock_cursor

    mock_db.connection_pool.getconn.return_value = mock_conn

    result = mock_db.get_name_rank("Noah")

    assert result is not None
    assert result["name"] == "Noah"
    assert result["rank"] == 1


def test_get_name_rank_not_found(mock_db):
    """Test getting rank for non-existent name."""
    mock_cursor = MagicMock()
    mock_cursor.fetchone.return_value = None

    mock_conn = MagicMock()
    mock_conn.cursor.return_value = mock_cursor

    mock_db.connection_pool.getconn.return_value = mock_conn

    result = mock_db.get_name_rank("UnknownName")

    assert result is None


def test_get_all_names(mock_db):
    """Test getting all names."""
    mock_cursor = MagicMock()
    mock_cursor.fetchall.return_value = [
        {"name": "Noah", "rank": 1, "count": 4382, "year": 2024},
        {"name": "Muhammad", "rank": 2, "count": 4258, "year": 2024},
    ]

    mock_conn = MagicMock()
    mock_conn.cursor.return_value = mock_cursor

    mock_db.connection_pool.getconn.return_value = mock_conn

    results = mock_db.get_all_names(limit=2)

    assert len(results) == 2
    assert results[0]["name"] == "Noah"


def test_health_check_success(mock_db):
    """Test successful health check."""
    mock_cursor = MagicMock()
    mock_conn = MagicMock()
    mock_conn.cursor.return_value = mock_cursor

    mock_db.connection_pool.getconn.return_value = mock_conn

    result = mock_db.health_check()

    assert result is True
    mock_cursor.execute.assert_called_once_with("SELECT 1")


def test_health_check_failure(mock_db):
    """Test failed health check."""
    mock_db.connection_pool.getconn.side_effect = Exception("Connection failed")

    result = mock_db.health_check()

    assert result is False


def test_connection_pool_management(mock_db):
    """Test connection pool get and return."""
    mock_conn = MagicMock()
    mock_db.connection_pool.getconn.return_value = mock_conn

    conn = mock_db.get_connection()
    assert conn == mock_conn

    mock_db.return_connection(conn)
    mock_db.connection_pool.putconn.assert_called_once_with(conn)
