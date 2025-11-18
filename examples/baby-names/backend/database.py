"""
Database connection and query module for baby names API.
"""

import os
from typing import Dict, List, Optional

import psycopg2
from psycopg2 import pool
from psycopg2.extras import RealDictCursor


class Database:
    """Database connection manager with connection pooling."""

    def __init__(self):
        """Initialize database connection pool."""
        self.connection_pool = None
        self._initialize_pool()

    def _initialize_pool(self):
        """Create PostgreSQL connection pool."""
        try:
            self.connection_pool = pool.SimpleConnectionPool(
                minconn=1,
                maxconn=10,
                host=os.getenv("DB_HOST", "localhost"),
                port=os.getenv("DB_PORT", "5432"),
                database=os.getenv("DB_NAME", "baby_names"),
                user=os.getenv("DB_USER", "app_user"),
                password=os.getenv("DB_PASSWORD", "app_password"),
            )
        except (Exception, psycopg2.DatabaseError) as error:
            print(f"Error creating connection pool: {error}")
            raise

    def get_connection(self):
        """Get a connection from the pool."""
        return self.connection_pool.getconn()

    def return_connection(self, conn):
        """Return a connection to the pool."""
        self.connection_pool.putconn(conn)

    def get_name_rank(self, name: str) -> Optional[Dict]:
        """
        Get rank information for a given baby name.

        Args:
            name: The baby name to search for (case-insensitive)

        Returns:
            Dictionary with name, rank, and count, or None if not found
        """
        conn = None
        try:
            conn = self.get_connection()
            cursor = conn.cursor(cursor_factory=RealDictCursor)

            query = """
                SELECT name, rank, count, year
                FROM baby_names
                WHERE LOWER(name) = LOWER(%s)
                LIMIT 1
            """

            cursor.execute(query, (name,))
            result = cursor.fetchone()
            cursor.close()

            return dict(result) if result else None

        except (Exception, psycopg2.DatabaseError) as error:
            print(f"Error querying database: {error}")
            return None
        finally:
            if conn:
                self.return_connection(conn)

    def get_all_names(self, limit: int = 100) -> List[Dict]:
        """
        Get all baby names (for testing purposes).

        Args:
            limit: Maximum number of names to return

        Returns:
            List of dictionaries containing name information
        """
        conn = None
        try:
            conn = self.get_connection()
            cursor = conn.cursor(cursor_factory=RealDictCursor)

            query = """
                SELECT name, rank, count, year
                FROM baby_names
                ORDER BY rank
                LIMIT %s
            """

            cursor.execute(query, (limit,))
            results = cursor.fetchall()
            cursor.close()

            return [dict(row) for row in results]

        except (Exception, psycopg2.DatabaseError) as error:
            print(f"Error querying database: {error}")
            return []
        finally:
            if conn:
                self.return_connection(conn)

    def health_check(self) -> bool:
        """
        Check if database is accessible.

        Returns:
            True if database is accessible, False otherwise
        """
        conn = None
        try:
            conn = self.get_connection()
            cursor = conn.cursor()
            cursor.execute("SELECT 1")
            cursor.close()
            return True
        except (Exception, psycopg2.DatabaseError) as error:
            print(f"Database health check failed: {error}")
            return False
        finally:
            if conn:
                self.return_connection(conn)

    def close_all_connections(self):
        """Close all connections in the pool."""
        if self.connection_pool:
            self.connection_pool.closeall()


# Global database instance
db = Database()
