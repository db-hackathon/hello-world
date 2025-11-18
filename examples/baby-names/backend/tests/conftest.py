"""
Pytest configuration file for backend tests.
Mocks database connections to prevent actual PostgreSQL connections during tests.
"""

from unittest.mock import MagicMock, patch

# Mock the database connection pool at module level, before any tests are collected
# This prevents the Database class from trying to connect to PostgreSQL when imported
_mock_pool = MagicMock()
_pool_patcher = patch("psycopg2.pool.SimpleConnectionPool", return_value=_mock_pool)
_pool_patcher.start()
