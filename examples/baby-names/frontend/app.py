"""
Frontend web UI for baby names lookup.
Serves HTML interface that calls the backend API.
"""

import os

import requests
from flask import Flask, render_template, request

app = Flask(__name__)

# Backend API URL from environment variable
BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:5000")


@app.route("/", methods=["GET"])
def index():
    """
    Render home page with search form and results.

    Query params:
        name: Baby name to search for (optional)
    """
    name = request.args.get("name", "").strip()
    result = None
    error = None

    if name:
        # Call backend API
        try:
            response = requests.get(f"{BACKEND_URL}/api/v1/names/{name}", timeout=5)

            if response.status_code == 200:
                result = response.json()
            elif response.status_code == 404:
                error = f'Name "{name}" not found in the 2024 rankings'
            else:
                error = "Error searching for name"

        except requests.exceptions.RequestException as e:
            error = f"Unable to connect to backend service: {e}"

    return render_template("index.html", name=name, result=result, error=error)


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint."""
    return {"status": "healthy"}, 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=False)
