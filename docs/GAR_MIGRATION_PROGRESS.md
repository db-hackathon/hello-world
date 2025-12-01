# GAR Migration Progress

## Status: In Progress

**Plan file**: `.claude/plans/dynamic-leaping-starling.md`

**Starting a new session**: Tell Claude:
> "Continue the GAR migration. Read `docs/GAR_MIGRATION_PROGRESS.md` for current status and `.claude/plans/dynamic-leaping-starling.md` for the full plan."

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

**Goal**: CD validates and pulls from GAR, verifies attestations (hard-fail)

- [ ] Update CD workflow with WIF authentication for GAR
- [ ] Update image validation to check GAR
- [ ] Add hard-fail attestation verification
- [ ] Update Helm values.yaml with GAR image repositories
- [ ] Test with dry-run
- [ ] Test staging deployment
- [ ] Merge PR 2

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

## PR 3: Terraform & Cleanup

**Goal**: Remove ghcr.io dependencies

- [ ] Add Artifact Registry Reader IAM to GCP SA module
- [ ] Remove ghcr-secret from k8s-namespace module
- [ ] Remove ghcr.io push from CI (GAR-only)
- [ ] Update CLAUDE.md documentation
- [ ] Update CHANGELOG.md
- [ ] Verify full pipeline without ghcr.io
- [ ] Merge PR 3

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
