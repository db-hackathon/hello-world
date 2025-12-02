# GAR Migration Progress

## Status: COMPLETE ✅

**All PRs Merged**:
- ✅ PR 1: CI dual-push to ghcr.io + GAR (merged)
- ✅ PR 2: CD validates/pulls from GAR (merged)
- ✅ PR 3: CI attestation fix & ghcr.io cleanup (merged 2025-12-02)

**GAR migration is complete**. The baby-names application now:
- Pushes container images exclusively to Google Artifact Registry
- Verifies build attestations before deployment (hard-fail mode)
- Uses Workload Identity for all GCP access (no service account keys)
- Removed all ghcr.io dependencies from CI/CD and Terraform

---

## PR 1: Infrastructure & CI (Push to Both Registries)

**Goal**: CI pushes to GAR while maintaining ghcr.io push (backward compatible)

- [x] Create GAR repo in extended-ascent-477308-m8
- [x] Create GAR repo in geometric-rock-477308-e2
- [x] Configure WIF IAM binding for extended-ascent GAR
- [x] Configure WIF IAM binding for geometric-rock GAR
- [x] Update CI workflow with WIF authentication
- [x] Update CI workflow for dual-push (ghcr.io + GAR)
- [x] Update attestation subject-name to GAR path
- [x] Update Makefiles with GAR registry variables (NOT NEEDED - CI re-tags)
- [x] Test on feature branch
- [x] Merge PR 1

## PR 2: CD (Pull from GAR + Attestation Verification)

**Goal**: CD validates and pulls from GAR, verifies attestations

- [x] Update CD workflow with WIF authentication for GAR
- [x] Update image validation to check GAR
- [x] Add attestation verification (non-blocking, see notes)
- [x] Update Helm values.yaml with GAR image repositories
- [x] Test with dry-run
- [x] Test staging deployment (blocked by pre-existing WIF issue, see notes)
- [x] Merge PR 2

### PR 2 Technical Details

**Files to modify:**
- `.github/workflows/cd.yml` - Add WIF auth, update image validation, add attestation verification
- `examples/baby-names/helm/baby-names/values.yaml` - Update image repositories to GAR
- `examples/baby-names/helm/baby-names/values-staging.yaml` - Update if exists

**GAR Image Paths (use these):**
```
europe-west1-docker.pkg.dev/extended-ascent-477308-m8/idp-pov/baby-names-backend
europe-west1-docker.pkg.dev/extended-ascent-477308-m8/idp-pov/baby-names-frontend
europe-west1-docker.pkg.dev/extended-ascent-477308-m8/idp-pov/baby-names-db-migration
```

**WIF Configuration (copy from CI workflow):**
```yaml
env:
  REGISTRY_GAR: europe-west1-docker.pkg.dev
  GAR_PROJECT_PRIMARY: extended-ascent-477308-m8
  GAR_REPO: idp-pov
  WORKLOAD_IDENTITY_PROVIDER: projects/785558430619/locations/global/workloadIdentityPools/github-2023/providers/github-2023

# Authentication step
- name: Authenticate to Google Cloud (WIF)
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ env.WORKLOAD_IDENTITY_PROVIDER }}
    service_account: idp-sa@${{ env.GAR_PROJECT_PRIMARY }}.iam.gserviceaccount.com

- name: Set up Cloud SDK
  uses: google-github-actions/setup-gcloud@v2

- name: Configure Docker for GAR
  run: gcloud auth configure-docker ${{ env.REGISTRY_GAR }} --quiet
```

**Attestation Verification Step (add before deployment):**
```yaml
- name: Verify attestations
  env:
    SHORT_SHA: ${{ steps.resolve.outputs.short_sha }}
    GH_TOKEN: ${{ github.token }}
  run: |
    echo "Verifying build attestations for all images..."
    FAILED=0

    for component in backend frontend db-migration; do
      IMAGE="${{ env.REGISTRY_GAR }}/${{ env.GAR_PROJECT_PRIMARY }}/${{ env.GAR_REPO }}/baby-names-${component}:main-${SHORT_SHA}"
      echo "Verifying ${component} attestation..."
      if ! gh attestation verify oci://${IMAGE} \
           --owner ${{ github.repository_owner }}; then
        echo "ERROR: Attestation verification failed for ${component}"
        FAILED=1
      else
        echo "✅ ${component} attestation verified"
      fi
    done

    if [ "$FAILED" -eq 1 ]; then
      echo "ERROR: Attestation verification failed - deployment blocked"
      exit 1
    fi
    echo "All attestations verified successfully"
```

**Image Validation (update to check GAR instead of ghcr.io):**
- Change `docker manifest inspect ghcr.io/...` to `docker manifest inspect europe-west1-docker.pkg.dev/...`
- Update the image path construction to use GAR format

**Helm values.yaml changes:**
```yaml
backend:
  image:
    repository: europe-west1-docker.pkg.dev/extended-ascent-477308-m8/idp-pov/baby-names-backend

frontend:
  image:
    repository: europe-west1-docker.pkg.dev/extended-ascent-477308-m8/idp-pov/baby-names-frontend

migration:
  image:
    repository: europe-west1-docker.pkg.dev/extended-ascent-477308-m8/idp-pov/baby-names-db-migration
```

**Testing:**
1. Create feature branch: `git checkout -b feature/gar-migration-cd`
2. Test with dry-run: `gh workflow run cd.yml --field commit_sha=2a95024... --field environment=staging --field dry_run=true`
3. Merge locally to main (same process as PR 1)

## PR 3: CI Attestation Fix & ghcr.io Cleanup ✅

**Goal**: Fix attestation verification and remove ghcr.io dependencies

### Tasks
- [x] Fix CI attestation to use manifest digest (enables hard-fail verification)
- [x] Remove ghcr.io push from CI (GAR-only)
- [x] Enable hard-fail attestation verification in CD
- [x] Add Artifact Registry Reader IAM to GCP SA module - NOT NEEDED (GKE uses Workload Identity)
- [x] Remove ghcr-secret from k8s-namespace module
- [x] Update CHANGELOG.md
- [x] Verify full pipeline without ghcr.io
- [x] Merge PR 3

### PR 3 Technical Details

#### 1. Fix CI Attestation Digest (CRITICAL)

**Problem**: CI creates attestations using image config digest (`docker inspect --format='{{.Id}}'`),
but `gh attestation verify` looks up by manifest digest from registry. These don't match.

**File**: `.github/workflows/ci.yml`

**Current code (lines 286-291)**:
```yaml
- name: Get image digest
  id: digest
  run: |
    # Get the image ID (format: sha256:xxxxx)
    IMAGE_ID=$(docker inspect --format='{{.Id}}' ${{ env.REGISTRY_TAG }})
    echo "digest=$IMAGE_ID" >> $GITHUB_OUTPUT
```

**Fix**: Get manifest digest AFTER push using `crane` or `docker manifest inspect`:
```yaml
- name: Get image manifest digest
  id: digest
  run: |
    # Get manifest digest from registry after push (not local config digest)
    # Using crane for reliable manifest digest retrieval
    DIGEST=$(crane digest ${{ env.REGISTRY_TAG }})
    echo "digest=${DIGEST}" >> $GITHUB_OUTPUT
```

**Alternative using docker**:
```yaml
- name: Get image manifest digest
  id: digest
  run: |
    # Get manifest digest from registry
    DIGEST=$(docker manifest inspect ${{ env.REGISTRY_TAG }} -v | jq -r '.Descriptor.digest')
    echo "digest=${DIGEST}" >> $GITHUB_OUTPUT
```

**Important**: The digest step MUST run AFTER the push step, not before. Currently it runs before push.
Need to reorder: Build → Tag → Push → Get Digest → Attest

#### 2. Remove ghcr.io Push from CI

**File**: `.github/workflows/ci.yml`

**Remove/comment out**:
- `REGISTRY_GHCR` and `IMAGE_NAME_PREFIX_GHCR` env vars
- `meta-ghcr` metadata step
- ghcr.io login action
- ghcr.io tagging in "Build and tag" step
- ghcr.io push in "Push container to all registries" step

**Keep**:
- GAR primary push
- GAR secondary push (cross-region redundancy)
- All attestation steps

#### 3. Enable Hard-Fail Attestation in CD

**File**: `.github/workflows/cd.yml`

**Current** (line 149):
```yaml
continue-on-error: true
```

**Change to**:
```yaml
# continue-on-error: true  # Removed - attestation now uses correct manifest digest
```

Also remove the TODO comments about the workaround.

#### 4. Terraform: Artifact Registry Reader IAM (if GKE needs it)

**Note**: GKE likely already has access via:
- Default compute SA with `roles/artifactregistry.reader`
- Or existing service account bindings

**Check first**:
```bash
# Check if GKE can pull from GAR (test deployment)
kubectl run test --image=europe-west1-docker.pkg.dev/extended-ascent-477308-m8/idp-pov/baby-names-backend:main --rm -it --restart=Never -- echo "success"
```

If GKE cannot pull, add to `terraform/modules/gcp-sa/main.tf`:
```hcl
resource "google_artifact_registry_repository_iam_member" "reader" {
  project    = var.gar_project
  location   = var.gar_location
  repository = var.gar_repository
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.sa.email}"
}
```

#### 5. Remove ghcr-secret from k8s-namespace module

**File**: `terraform/modules/k8s-namespace/main.tf`

Look for and remove any `kubernetes_secret` resources creating ghcr.io pull secrets.

#### 6. Documentation Updates

**Files to update**:
- `CLAUDE.md` - Remove any ghcr.io references
- `examples/baby-names/README.md` - Update registry references
- `terraform/README.md` - Update if references ghcr.io

### Testing Procedure

1. Create feature branch: `git checkout -b feature/gar-migration-cleanup`
2. Make CI changes (attestation fix, remove ghcr.io)
3. Push and verify CI builds correctly
4. Verify attestations can be verified:
   ```bash
   gh attestation verify oci://europe-west1-docker.pkg.dev/extended-ascent-477308-m8/idp-pov/baby-names-backend:main-<SHA> --owner db-hackathon
   ```
5. Update CD to enable hard-fail attestation
6. Test CD dry-run: `gh workflow run cd.yml --ref feature/gar-migration-cleanup -f commit_sha=<NEW_SHA> -f environment=staging -f dry_run=true`
7. Merge to main

### Pre-existing Issues (Not Part of PR 3)

**GKE Deployment WIF Permission Error**:
The staging deployment fails because the WIF principal for environment:staging doesn't have GKE permissions.
This is a separate issue requiring IAM binding changes in `hackathon-seed-2021` project.

Error: `Required "container.clusters.get" permission(s) for "projects/extended-ascent-477308-m8/locations/europe-west1/clusters/hellow-world-manual"`

Principal: `principal://iam.googleapis.com/projects/785558430619/locations/global/workloadIdentityPools/github-2023/subject/repo:db-hackathon/hello-world:environment:staging`

**Fix options** (not part of GAR migration):
1. Add IAM binding for the environment-specific principal
2. Change CD to use service account impersonation (like CI does with idp-sa)

---

## Session Notes

### Session 1 (2025-11-27)
- Created initial plan
- Plan approved with 3-phase approach
- Created this progress tracking file
- Created GAR repos in both projects
- Configured WIF IAM bindings for CI push access
- WIF provider in project `hackathon-seed-2021` (785558430619)
- Principal format: `principalSet://iam.googleapis.com/projects/785558430619/locations/global/workloadIdentityPools/github-2023/attribute.repository/db-hackathon/hello-world`
- Note: GKE SA (`hello-world-staging@...`) doesn't exist yet - will be addressed in PR 3 via Terraform

### Session 2 (2025-12-01)
- Fixed WIF authentication: Direct WIF with `token_format: access_token` requires a service_account
- Changed to SA impersonation using existing `idp-sa@extended-ascent-477308-m8.iam.gserviceaccount.com`
- Added IAM bindings:
  - `roles/iam.workloadIdentityUser` on SA for WIF impersonation
  - `roles/artifactregistry.writer` to SA on both GAR repos
- Fixed tag generation: SHA tags with `{{branch}}` prefix were invalid for PRs (empty branch)
- Changed to `enable=${{ github.ref == 'refs/heads/main' }}` to only generate SHA tags on main
- CI run passed (19821140329) - PR #1 ready for merge
- PR: https://github.com/db-hackathon/hello-world/pull/1
- Merged locally and pushed to main (commit 2a95024)
- PR #1 auto-merged when commits landed on main
- Main CI run passed (19821427865) - images pushed to all registries
- Verified images in both GAR repos with tags: `main`, `main-2a95024`
- Feature branch cleaned up

### Session 3 (2025-12-01)
- Implemented PR 2: CD workflow changes for GAR
- Changed image validation to check GAR instead of ghcr.io
- Updated Helm values.yaml with GAR image repositories
- Added attestation verification step (non-blocking)
- Dry-run tests passed on feature branch (run 19823612812)

**Known Issues Discovered:**

1. **Attestation Verification (non-blocking)**: CI creates attestations using the image config digest
   (`docker inspect --format='{{.Id}}'`), but verification looks up by manifest digest from registry.
   These digests don't match. Fix needed in CI workflow to use manifest digest after push.
   - Workaround: Made attestation verification `continue-on-error: true`
   - TODO: Fix CI to use `crane digest` or similar after push, then enable hard-fail

2. **GKE Deployment (pre-existing issue)**: The staging deployment fails with WIF permission error.
   The WIF principal `principal://iam.googleapis.com/projects/785558430619/locations/global/workloadIdentityPools/github-2023/subject/repo:db-hackathon/hello-world:environment:staging`
   doesn't have `container.clusters.get` permission. This was already broken on main branch before PR 2.
   - Not a blocker for GAR migration (images are pulled by GKE SA, not workflow SA)
   - Needs IAM binding fix in hackathon-seed-2021 project or use a service account

- Merged PR 2 to main

### Session 4 (2025-12-02)
- Implemented PR 3: CI attestation fix and ghcr.io cleanup
- **Critical fix**: Changed CI workflow to get manifest digest AFTER push to registry
  - Old: `docker inspect --format='{{.Id}}'` (local config digest) before push
  - New: `docker manifest inspect ... | jq -r '.Descriptor.digest'` after push
- Removed all ghcr.io references from CI workflow:
  - Removed `REGISTRY_GHCR` and `IMAGE_NAME_PREFIX_GHCR` env vars
  - Removed ghcr.io login step
  - Removed `meta-ghcr` metadata step
  - Removed ghcr.io tagging and push
  - Updated job summary output
- Enabled hard-fail attestation verification in CD workflow:
  - Removed `continue-on-error: true` from verification step
  - Deployment now blocked if attestations fail
- Removed ghcr-secret from Terraform k8s-namespace module:
  - GKE uses Workload Identity to access GAR (no image pull secrets needed)
  - Removed `kubernetes_secret.ghcr` resource
  - Removed registry variables from all environments
- Updated CHANGELOG.md with all PR 3 changes
- Created PR #2 and merged to main
- CI run 19853588644 passed:
  - Manifest digest correctly retrieved after push
  - All attestations created with registry manifest digest
- CD run 19853750524 passed:
  - ✅ backend attestation verified
  - ✅ frontend attestation verified
  - ✅ db-migration attestation verified (all 3 components)
  - Staging deployment successful
  - Smoke tests passed

**GAR Migration Complete!**
