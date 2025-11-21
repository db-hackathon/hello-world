# Baby Names Rank Finder

A three-tier web application that allows users to search for UK baby name rankings based on the 2024 Office for National Statistics (ONS) dataset.

## Overview

This application demonstrates a complete three-tier architecture with:
- **Frontend**: Flask web application with HTML templates
- **Backend**: Flask REST API
- **Database**: PostgreSQL with Liquibase schema management

The application uses real 2024 ONS data for boys' baby names in England and Wales.

## Architecture

```
┌─────────────────┐
│    Frontend     │  Flask web app (port 8080)
│   (Python 3.11) │  Renders HTML, calls backend API
└────────┬────────┘
         │ HTTP
         ▼
┌─────────────────┐
│     Backend     │  Flask REST API (port 5000)
│   (Python 3.11) │  Provides /api/v1/names endpoints
└────────┬────────┘
         │ SQL
         ▼
┌─────────────────┐
│   PostgreSQL    │  Database (port 5432)
│    Database     │  Managed by Liquibase
└─────────────────┘
```

### Components

#### Frontend (`frontend/`)
- **Technology**: Python 3.11, Flask, Jinja2 templates
- **Port**: 8080
- **Purpose**: User interface for searching baby names
- **Features**:
  - Simple HTML form for name search
  - Displays rank, count, and year
  - Error handling for API failures

#### Backend (`backend/`)
- **Technology**: Python 3.11, Flask, psycopg2
- **Port**: 5000
- **Purpose**: REST API for name data
- **Endpoints**:
  - `GET /health` - Health check with database status
  - `GET /api/v1/names/<name>` - Get rank for specific name
  - `GET /api/v1/names?limit=N` - List all names (default 100)
- **Features**:
  - Connection pooling for database efficiency
  - CORS enabled for frontend access
  - Case-insensitive name search
  - Comprehensive error handling

#### Database (`database/`)
- **Technology**: PostgreSQL 15, Liquibase
- **Port**: 5432
- **Schema**:
  ```sql
  CREATE TABLE baby_names (
      id SERIAL PRIMARY KEY,
      name VARCHAR(100) NOT NULL UNIQUE,
      rank INTEGER NOT NULL,
      count INTEGER NOT NULL,
      year INTEGER NOT NULL DEFAULT 2024
  );
  ```
- **Data**: 2024 ONS boys' baby names dataset (complete dataset)
- **Indexes**: On `name` and `rank` columns for query performance

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Python 3.11 (for local development)
- Git

### Running Locally with Docker Compose

1. **Clone the repository**:
   ```bash
   cd examples/baby-names
   ```

2. **Start all services**:
   ```bash
   docker-compose up -d
   ```

3. **Wait for services to be ready** (about 30 seconds):
   ```bash
   # Check backend health
   curl http://localhost:5000/health

   # Check frontend health
   curl http://localhost:8080/health
   ```

4. **Access the application**:
   - Frontend: http://localhost:8080
   - Backend API: http://localhost:5000/api/v1/names

5. **Try searching for a name**:
   - Go to http://localhost:8080
   - Enter "Noah" or "Muhammad" in the search box
   - View the ranking results

6. **Stop services**:
   ```bash
   docker-compose down
   ```

7. **Stop and remove data**:
   ```bash
   docker-compose down -v
   ```

### Running Tests

#### Unit Tests

Unit tests mock external dependencies and test individual components:

```bash
# Backend unit tests
cd backend
pip install -r requirements.txt
pip install pytest pytest-cov
pytest tests/ -v

# Frontend unit tests
cd frontend
pip install -r requirements.txt
pip install pytest pytest-cov
pytest tests/ -v
```

#### Integration Tests

Integration tests require all services to be running via docker-compose:

```bash
# Start services
docker-compose up -d

# Wait for services to be ready
sleep 30

# Run integration tests
pytest tests/integration/ -v

# Cleanup
docker-compose down -v
```

Integration tests verify:
- End-to-end data flow from frontend → backend → database
- Real HTTP requests between services
- Database connectivity and queries
- Case-insensitive name search
- Data consistency across tiers

#### Smoke Tests

Smoke tests are lightweight post-deployment verification tests:

```bash
# With services running
export BACKEND_URL=http://localhost:5000
export FRONTEND_URL=http://localhost:8080
pytest tests/smoke/ -v
```

Smoke tests verify:
- Services are responding
- Health checks pass
- Critical user path works (search for a name)
- Top names are in database

## API Documentation

### Health Check

**Endpoint**: `GET /health`

**Response**:
```json
{
  "status": "healthy",
  "database": "connected"
}
```

**Status Codes**:
- `200 OK` - Service is healthy
- `503 Service Unavailable` - Database connection failed

### Get Name Rank

**Endpoint**: `GET /api/v1/names/<name>`

**Example**: `GET /api/v1/names/Noah`

**Response**:
```json
{
  "name": "Noah",
  "rank": 1,
  "count": 4382,
  "year": 2024
}
```

**Status Codes**:
- `200 OK` - Name found
- `404 Not Found` - Name not in database
- `400 Bad Request` - Invalid name parameter

### List All Names

**Endpoint**: `GET /api/v1/names?limit=<N>`

**Parameters**:
- `limit` (optional): Number of names to return (default: 100)

**Example**: `GET /api/v1/names?limit=10`

**Response**:
```json
{
  "names": [
    {
      "name": "Noah",
      "rank": 1,
      "count": 4382,
      "year": 2024
    },
    {
      "name": "Muhammad",
      "rank": 2,
      "count": 4258,
      "year": 2024
    }
  ],
  "count": 2
}
```

## Development

### Local Development Setup

#### Backend

```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt

# Set environment variables
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=baby_names
export DB_USER=app_user
export DB_PASSWORD=app_password

# Run the backend
python app.py
```

#### Frontend

```bash
cd frontend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt

# Set environment variable
export BACKEND_URL=http://localhost:5000

# Run the frontend
python app.py
```

### Code Quality

The project uses:
- **flake8**: Linting and style checking
- **black**: Code formatting
- **pytest**: Testing framework
- **pytest-cov**: Code coverage

```bash
# Lint code
flake8 backend/ frontend/

# Format code
black backend/ frontend/

# Run tests with coverage
pytest --cov=backend backend/tests/
pytest --cov=frontend frontend/tests/
```

## Running CI Locally

The CI pipeline can be executed locally using Make commands. This allows you to test changes before pushing to GitHub.

### Prerequisites

**Phase A** - The Makefile automatically installs Python tools (ruff, safety, pytest) when you run Phase A commands.

**Phase B** - You need to manually install these tools for container building and scanning:

```bash
# Install Docker or Podman (required for building containers)
# See: https://docs.docker.com/get-docker/

# Install Syft for SBOM generation
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Install Trivy for vulnerability scanning
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh
```

**Note**: For Phase A only, you don't need to install anything - just run `make phase-a` and the Makefile handles it!

### Phase A - Quality Gates (Sequential)

Run these commands from the `examples/baby-names` directory:

```bash
cd examples/baby-names

# Check code formatting
make format-check

# Run linting
make lint

# Run dependency security scan (fails on CRITICAL vulnerabilities)
make security-check

# Run unit tests
make test

# Run all Phase A checks
make phase-a
```

### Phase B - Build & Scan (Parallel)

```bash
# Build all container images
make build-all

# Generate SBOMs for all containers
make generate-sbom-all

# Scan containers for CRITICAL vulnerabilities
make scan-all

# Run all Phase B steps
make phase-b
```

### Full CI Pipeline

```bash
# Run complete CI pipeline locally
make ci-local
```

### Component-Specific Commands

You can also run commands for individual components:

```bash
# Backend
cd examples/baby-names/backend
make lint          # Lint backend code
make test          # Run backend tests
make build         # Build backend container
make scan          # Scan backend container

# Frontend
cd examples/baby-names/frontend
make lint          # Lint frontend code
make test          # Run frontend tests
make build         # Build frontend container
make scan          # Scan frontend container

# Database migration
cd examples/baby-names/database
make build         # Build migration container
make scan          # Scan migration container
```

### Verifying Locally

Before pushing changes, verify everything passes:

```bash
# From examples/baby-names directory
cd examples/baby-names
make ci-local

# If Phase A passes and Phase B passes, you're good to push!
```

## CI/CD Pipeline

### Continuous Integration (CI)

The CI pipeline (`.github/workflows/ci.yml`) implements a two-phase approach with fail-fast behavior:

#### Phase A - Sequential Quality Gates

These run sequentially and any failure stops the pipeline:

1. **Format & Lint Check**
   - Uses `ruff` for fast Python linting and formatting
   - Runs for backend and frontend
   - Generates and attests lint result artifacts
   - **Locally executable**: `make lint`

2. **Dependency Security Scan**
   - Uses `safety` to scan dependencies for vulnerabilities
   - Fails only on CRITICAL vulnerabilities (configured via `.safety-policy.yml`)
   - Generates and attests security report artifacts
   - **Locally executable**: `make security-check`

3. **Unit Tests**
   - Runs pytest for backend and frontend
   - Generates code coverage reports
   - Attests coverage artifacts
   - Uploads coverage to Codecov
   - **Locally executable**: `make test`

#### Phase B - Parallel Build, Scan & Attest

These run in parallel after Phase A completes successfully:

For each component (backend, frontend, db-migration):

1. **Build Container Image**
   - Builds Docker image locally (doesn't push yet)
   - Uses BuildKit with layer caching
   - **Locally executable**: `make build-all`

2. **Generate SBOM**
   - Uses Syft to generate SPDX-format SBOM
   - Creates comprehensive software bill of materials
   - **Locally executable**: `make generate-sbom-all`

3. **Scan for Vulnerabilities**
   - Uses Trivy to scan container images
   - Fails on CRITICAL vulnerabilities
   - Generates scan results in JSON format
   - **Locally executable**: `make scan-all`

4. **Attest SBOM** (GitHub Actions only)
   - Creates signed attestation for SBOM using GitHub Actions
   - Binds SBOM to container image digest
   - Verifiable with `gh attestation verify`

5. **Attest Build Provenance** (GitHub Actions only)
   - Creates SLSA build provenance attestation
   - Records build environment, inputs, and dependencies
   - Ensures supply chain integrity

6. **Push to Registry**
   - Pushes container to GitHub Container Registry (ghcr.io)
   - Only happens if all previous steps pass
   - Only on pushes to main branch (not PRs)

### Security Features

- **Fail-Fast**: Phase A stops at first failure, preventing wasted compute
- **Critical Vulnerabilities Only**: Only CRITICAL severity blocks the build
- **Attestations**: All artifacts and containers are cryptographically signed
- **SBOM**: Complete software bill of materials for each container
- **Local Execution**: >90% of CI is runnable locally for faster iteration

### Continuous Deployment (CD)

The CD pipeline (`.github/workflows/cd.yml`) handles deployment:

1. **Integration Tests**
   - Starts all services with docker-compose
   - Runs integration tests against running services
   - Verifies end-to-end functionality

2. **Deploy to Staging** (automatic on main branch)
   - Pulls latest container images
   - Deploys to staging Kubernetes cluster (currently stubbed)
   - Waits for rollout completion

3. **Smoke Tests (Staging)**
   - Runs smoke tests against staging environment
   - Verifies critical user paths
   - Checks service health

4. **Deploy to Production** (manual approval required)
   - Requires manual approval via GitHub Environments
   - Performs blue-green or canary deployment
   - Gradual traffic shift with monitoring

5. **Smoke Tests (Production)**
   - Verifies production deployment
   - Validates SSL certificates
   - Checks response times

**Note**: Actual deployment steps are currently stubbed. They will be implemented when infrastructure is ready.

## Data Source

This application uses the official 2024 baby names data from the UK Office for National Statistics (ONS):

- **Source**: [Baby names in England and Wales: 2024](https://www.ons.gov.uk/peoplepopulationandcommunity/birthsdeathsandmarriages/livebirths/datasets/babynamesenglandandwalesbabynamesstatisticsboys)
- **Dataset**: Boys' names registered in England and Wales in 2024
- **Format**: Rank, name, count, year
- **Top 3 Names**: Noah (#1), Muhammad (#2), Oliver (#3)

## Deployment

### GKE Deployment (Staging)

The application is deployed to Google Kubernetes Engine using Helm:

**Infrastructure Status**: ✅ Configured
- **Cluster**: `hellow-world-manual` in `europe-west1`
- **Database**: CloudSQL instance `hello-world-manual` with IAM authentication
- **Namespace**: `baby-names-staging`
- **Ingress**: GCE ingress at `gke-df4e635bf6a042d9a06ccadd5f88beab6860-254825841253.europe-west1.gke.goog`

**Helm Chart**: Located in `helm/baby-names/` with environment-specific values files
- `values.yaml`: Default configuration
- `values-staging.yaml`: Staging environment overrides

**Deployment Command**:
```bash
cd helm/baby-names
helm upgrade --install baby-names . \
  --namespace baby-names-staging \
  --create-namespace \
  --values values-staging.yaml \
  --set backend.image.tag=main \
  --set frontend.image.tag=main \
  --set migration.image.tag=main \
  --wait --timeout 10m
```

**Required Infrastructure Components**:

1. **Cloud NAT** (for private GKE cluster egress):
   ```bash
   gcloud compute routers create nat-router \
     --network default \
     --region europe-west1 \
     --project extended-ascent-477308-m8

   gcloud compute routers nats create nat-config \
     --router nat-router \
     --region europe-west1 \
     --nat-all-subnet-ip-ranges \
     --auto-allocate-nat-external-ips \
     --project extended-ascent-477308-m8
   ```

2. **ImagePullSecret** (for GitHub Container Registry):
   ```bash
   kubectl create secret docker-registry ghcr-secret \
     --docker-server=ghcr.io \
     --docker-username=<GITHUB_USERNAME> \
     --docker-password=<GITHUB_PAT> \
     --docker-email=noreply@github.com \
     -n baby-names-staging

   kubectl patch serviceaccount baby-names-staging \
     -n baby-names-staging \
     -p '{"imagePullSecrets": [{"name": "ghcr-secret"}]}'
   ```
   Note: GitHub PAT requires `read:packages` scope

3. **Workload Identity Binding** (K8s SA to GCP SA):
   ```bash
   gcloud iam service-accounts add-iam-policy-binding \
     hello-world-staging@extended-ascent-477308-m8.iam.gserviceaccount.com \
     --role roles/iam.workloadIdentityUser \
     --member "serviceAccount:extended-ascent-477308-m8.svc.id.goog[baby-names-staging/baby-names-staging]" \
     --project extended-ascent-477308-m8
   ```

4. **Cloud SQL Client Role**:
   ```bash
   gcloud projects add-iam-policy-binding extended-ascent-477308-m8 \
     --member="serviceAccount:hello-world-staging@extended-ascent-477308-m8.iam.gserviceaccount.com" \
     --role="roles/cloudsql.client" \
     --condition=None
   ```

5. **Cloud SQL Admin API**:
   ```bash
   gcloud services enable sqladmin.googleapis.com --project=extended-ascent-477308-m8
   ```

6. **IAM Database User**:
   ```bash
   gcloud sql users create "hello-world-staging@extended-ascent-477308-m8.iam" \
     --instance=hello-world-manual \
     --type=CLOUD_IAM_SERVICE_ACCOUNT \
     --project extended-ascent-477308-m8
   ```

**Continuous Deployment**: Automated via `.github/workflows/cd.yml`
- Triggered on push to `main` branch
- Uses Direct Workload Identity Federation (no service account keys)
- Deploys with commit SHA as image tag
- Runs smoke tests post-deployment

**Known Limitations**:
- PostgreSQL GRANT permissions for IAM database user require manual configuration
- See CHANGELOG.md for complete infrastructure setup history

### Local Development

For local development and testing:
```bash
cd examples/baby-names
export DOCKER_HOST=unix:///run/user/1000/podman/podman.sock
docker-compose up -d
```

See "Running the Application" section above for complete local setup instructions.

## Environment Variables

### Backend

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_HOST` | PostgreSQL host | `localhost` |
| `DB_PORT` | PostgreSQL port | `5432` |
| `DB_NAME` | Database name | `baby_names` |
| `DB_USER` | Database user | `app_user` |
| `DB_PASSWORD` | Database password | `app_password` |
| `PORT` | Backend API port | `5000` |

### Frontend

| Variable | Description | Default |
|----------|-------------|---------|
| `BACKEND_URL` | Backend API URL | `http://localhost:5000` |
| `PORT` | Frontend port | `8080` |

### Integration/Smoke Tests

| Variable | Description | Default |
|----------|-------------|---------|
| `BACKEND_URL` | Backend API URL for tests | `http://localhost:5000` |
| `FRONTEND_URL` | Frontend URL for tests | `http://localhost:8080` |

## Troubleshooting

### Services won't start

**Problem**: `docker-compose up` fails

**Solutions**:
```bash
# Check if ports are already in use
lsof -i :5432  # PostgreSQL
lsof -i :5000  # Backend
lsof -i :8080  # Frontend

# Remove old containers and volumes
docker-compose down -v

# Rebuild images
docker-compose build --no-cache
docker-compose up -d
```

### Database connection errors

**Problem**: Backend can't connect to database

**Solutions**:
```bash
# Check database is healthy
docker-compose ps postgres

# View database logs
docker-compose logs postgres

# Verify database is ready
docker-compose exec postgres pg_isready -U app_user

# Check Liquibase migration completed
docker-compose logs db-migration
```

### Tests fail

**Problem**: Integration or smoke tests fail

**Solutions**:
```bash
# Ensure services are running and healthy
curl http://localhost:5000/health
curl http://localhost:8080/health

# Check service logs
docker-compose logs backend
docker-compose logs frontend

# Restart services
docker-compose restart backend frontend
```

### Name not found

**Problem**: Searching for a name returns 404

**Solutions**:
- Verify the name spelling (case-insensitive)
- Check if name is in the 2024 ONS boys dataset
- Query the database directly:
  ```bash
  docker-compose exec postgres psql -U app_user -d baby_names -c "SELECT * FROM baby_names WHERE name = 'YourName';"
  ```

## License

This is a demonstration application for Internal Developer Platform (IDP) capabilities.

## Contributing

This application is part of a larger IDP demonstration project. For contributions, please refer to the main project README.
