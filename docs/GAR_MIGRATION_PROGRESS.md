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
