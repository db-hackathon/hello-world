"""
Backend REST API for baby names lookup.
Provides endpoints to query baby name rankings from the database.
"""

from flask import Flask, jsonify, request
from flask_cors import CORS

from database import db

app = Flask(__name__)
CORS(app)  # Enable CORS for frontend access


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint."""
    db_healthy = db.health_check()

    return jsonify(
        {"status": "healthy" if db_healthy else "unhealthy", "database": "connected" if db_healthy else "disconnected"}
    ), 200 if db_healthy else 503


@app.route("/api/v1/names/<name>", methods=["GET"])
def get_name(name):
    """
    Get rank information for a specific baby name.

    Args:
        name: Baby name to look up

    Returns:
        JSON response with rank information or error
    """
    if not name or len(name.strip()) == 0:
        return jsonify({"error": "Name parameter is required"}), 400

    result = db.get_name_rank(name)

    if result:
        return jsonify({"name": result["name"], "rank": result["rank"], "count": result["count"], "year": result["year"]}), 200
    else:
        return jsonify({"error": f'Name "{name}" not found in database', "name": name}), 404


@app.route("/api/v1/names", methods=["GET"])
def get_all_names():
    """
    Get all baby names (for testing).

    Query params:
        limit: Maximum number of results (default 100, max 500)

    Returns:
        JSON array of name records
    """
    try:
        limit = int(request.args.get("limit", 100))
        limit = min(limit, 500)  # Cap at 500
    except ValueError:
        limit = 100

    results = db.get_all_names(limit=limit)

    return jsonify({"count": len(results), "names": results}), 200


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors."""
    return jsonify({"error": "Endpoint not found"}), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors."""
    return jsonify({"error": "Internal server error"}), 500


if __name__ == "__main__":
    # Run Flask app
    app.run(host="0.0.0.0", port=5000, debug=False)
