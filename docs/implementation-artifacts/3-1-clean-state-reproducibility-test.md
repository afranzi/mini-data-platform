---
baseline_commit: 8ad8f0157144e141dd702ee8e70ea0ead36d3c69
---

# Story 3.1: Clean-State Reproducibility Test

Status: ready-for-dev

## Story

As a platform operator,
I want the whole platform to come up from a clean `terraform apply` with ArgoCD self-reconciling,
so that the Airflow 3 / k8s 1.33 upgrade is reproducible with no manual post-steps (NFR1, SM1).

## ⚠️ Operator Prerequisites (host-level, unavoidable on the docker driver)

These are environment prerequisites, **not** "manual post-steps" of the platform (analogous to "docker must be running"):

1. **Docker running**; `data` minikube profile may exist or not (this story destroys/recreates it).
2. **Tunnel (real terminal, sudo):** `sudo minikube tunnel -p data` must be running for the `argocd` Terraform provider to reach `argocd.data:443` and for UI access. The tunnel can only start **after** the cluster + ArgoCD ingress exist (so a first apply may need the two-phase ordering in Task 2).
3. **/etc/hosts:** `127.0.0.1 argocd.data airflow.data` (docker tunnel binds localhost — NOT the node IP; corrected in Story 2.7). Re-confirm after recreate.

> The destroy/recreate is **live and destructive**. The dev agent MUST get explicit operator go-ahead before `terraform destroy` / cluster deletion (the cluster is local/disposable per NFR5, but it is still a real teardown).

## Acceptance Criteria

1. **Clean teardown.** Starting from the current running stack, `terraform destroy` (or `minikube delete -p data` + state reset) removes the cluster and all workloads cleanly, leaving a clean state.
2. **Single-pass `terraform apply` stands up the full platform (NFR1, SM1).** From clean, `terraform apply` brings up: minikube k8s **v1.33.4** (node Ready), ArgoCD, the `mini-data-platform` ArgoCD Project, and the `postgres` + `airflow` Applications — with **zero manual platform steps** beyond the host prerequisites above. Any unavoidable apply-ordering (e.g. the argocd-provider bootstrap) is **encoded/documented**, not improvised.
3. **ArgoCD auto-reconciles to Synced/Healthy (NFR1).** All Applications reach **Synced/Healthy automatically** — without a manual `argocd app sync` / `kubectl patch operation`. ⚠️ **Known gap (from Story 2.7):** the generic `modules/k8s/argocd/application` module currently sets **no `syncPolicy`**, so apps stay `OutOfSync` until synced by hand. This story MUST add `syncPolicy.automated` (with `prune` + `selfHeal`) so reconciliation is automatic — that is the core deliverable making AC3 true.
4. **End-state matches Story 2.7's verified state.** After the clean apply: all Airflow 3 components Running, migrate sync-hook completed, `my_dag_name` parses, `/api/v2/monitor/health` healthy. (Re-run the key 2.7 checks; a full manual DAG run is optional here since 2.7 proved it.)
5. **Reproducibility documented (SM1).** The exact clean-bring-up procedure (prerequisites + command sequence + any apply-ordering) is recorded in the repo (a runbook section), so a future operator can reproduce with no tribal knowledge.

> ⚠️ **Scope boundary:** prove + encode reproducibility. The one expected code change is adding `syncPolicy.automated` to the ArgoCD application module (+ any documented apply-ordering). NOT a place to re-architect topology. If the clean apply reveals a deeper defect, capture it (correct-course) rather than expanding scope.

## Tasks / Subtasks

- [ ] **Task 0 — Pre-flight + operator go-ahead (gate)**
  - [ ] Confirm prerequisites: tunnel running, `/etc/hosts` → `127.0.0.1`. Capture the current `git rev-parse HEAD` (deploy revision) and current `terraform state list` for comparison.
  - [ ] **HALT for explicit operator approval of the destroy/recreate** before any teardown.
- [ ] **Task 1 — Add automated syncPolicy to the ArgoCD application module (AC: 3)**
  - [ ] In `terraform/modules/k8s/argocd/application/01-application.tf`, add a `sync_policy { automated { prune = true, self_heal = true } }` block to `argocd_application.apps` (oboukili/argocd v6 schema). Consider `sync_options` (e.g. `CreateNamespace=false`, `ServerSideApply=true` if needed). Keep it parameterizable if other apps shouldn't auto-prune (default on is fine for this 2-app platform).
  - [ ] `terraform fmt` + `terraform validate`. Confirm `module.application_db` + `module.application` both inherit the policy (or are explicitly opted-in).
  - [ ] Commit to `main` (deploy branch) so the clean apply picks it up.
- [ ] **Task 2 — Clean teardown + single-pass apply (AC: 1, 2)**
  - [ ] With operator approval: `cd terraform/main && terraform destroy` (or `minikube delete -p data` if destroy is blocked by the argocd provider being unable to reach a torn-down server — document whichever path works). Confirm clean state.
  - [ ] Start/confirm `sudo minikube tunnel -p data` once the cluster + ingress exist. If the argocd provider can't be configured on a from-scratch apply (chicken-and-egg: provider config references `module.argocd` outputs before ArgoCD exists), use and **document** the bootstrap ordering: e.g. `terraform apply -target=module.cluster -target=module.argocd` first (bring up cluster + ArgoCD + ingress), start the tunnel, then `terraform apply` for the Project + Applications + secrets. Capture the exact sequence that works.
  - [ ] Record `terraform apply` output: all resources created, k8s `v1.33.4`, node Ready.
- [ ] **Task 3 — Verify automatic reconciliation (AC: 3, 4)**
  - [ ] WITHOUT any manual sync, confirm `kubectl -n argocd get applications` → both `postgres` + `airflow` reach **Synced/Healthy** on their own (auto-sync). If they don't, the syncPolicy is wrong — fix Task 1 and re-test.
  - [ ] Re-run the 2.7 health checks: all components Running, migrate job completed, `airflow dags list` → `my_dag_name` no import errors, `/api/v2/monitor/health` all-healthy.
- [ ] **Task 4 — Document the reproducibility runbook (AC: 5)**
  - [ ] Add a concise "clean bring-up" runbook (prerequisites + exact command sequence incl. any `-target` bootstrap + tunnel timing) to the repo — `terraform/main/readme.md` quickstart or a dedicated `docs/` runbook. (Coordinate with Story 3.4 docs regen; keep auto-generated `<!-- BEGIN_TF_DOCS -->` blocks untouched.)
  - [ ] Note the host prerequisites + the SimpleAuth ephemeral-password retrieval (from 2.7 deferred) so a fresh bring-up can actually log in.
- [ ] **Task 5 — Finalize**
  - [ ] `pre-commit` on touched files; revert unrelated argocd `<br>`→`<br/>` doc churn (known gotcha).
  - [ ] Capture evidence (destroy + apply logs, auto-sync proof, health) in the Dev Agent Record. Update `deferred-work.md` if anything new surfaces. Commit with the `Co-Authored-By` line.

## Dev Notes

### Critical guardrails

- **The automated syncPolicy is the crux.** Story 2.7 deployed by **manually** patching the Application `operation` field — proving the apps do NOT self-reconcile today. NFR1/AC3 ("ArgoCD reconciles automatically") cannot pass without `sync_policy.automated`. This is the one real code change. After adding it, a clean apply should self-sync with no `kubectl patch`.
- **argocd-provider bootstrap ordering (likely real).** The `provider "argocd"` block (`terraform/main/10-argocd.tf`) sets `server_addr = "${module.argocd.argocd_server}:443"` and `password = module.argocd.argocd_token`. On a from-scratch apply these reference resources that don't exist yet → the provider may fail to configure before ArgoCD is installed. Expect to need a two-phase apply (`-target=module.cluster -target=module.argocd` first, start tunnel, then full apply). This is a known oboukili/argocd pattern — **document it as the reproducible procedure** rather than calling the platform non-reproducible. "Zero manual post-steps" = zero *workload* steps; the provider bootstrap is an apply-ordering detail.
- **Tunnel timing.** The tunnel can only start after the cluster + ingress-nginx exist. So: cluster/ArgoCD up → start `sudo minikube tunnel -p data` → apply the argocd resources. Sequence matters.
- **random_* regenerate on recreate** (no `keepers`). Fresh cluster = fresh metadata DB, so fernet rotation is harmless (per PRD the metadata DB is disposable). Expected, not a defect.
- **gitSync/ArgoCD read `main`** (`target_revision: HEAD`). All cutover code is on `main` (merged in 2.7), so a clean apply reproduces the verified state. Don't point revisions at feature branches.
- **Deploy only via ArgoCD**; `terraform apply` provisions Project/Apps/secrets, ArgoCD reconciles. Manual `kubectl` is read-only verification.

### Current state (files in play)

- `terraform/modules/k8s/argocd/application/01-application.tf` (UPDATE) — the `argocd_application.apps` resource. Currently `spec { source{...}, destination{...} }` with **no `sync_policy`**. Add `sync_policy.automated`. Read it fully before editing; preserve the `helm { value_files, values, dynamic parameter }` block.
- `terraform/main/10-argocd.tf` (READ) — argocd provider config (bootstrap ordering source).
- `terraform/main/12-airflow.tf` (READ) — Project + `postgres`/`airflow` apps + secrets (finalized in 2.6/2.7; should not need changes).
- `terraform/main/readme.md` (UPDATE, Task 4) — add the clean bring-up runbook. NOTE: its socket_vmnet/qemu quickstart is stale (deferred → Story 3.4); align here or coordinate.

### Testing standards

- Live verification (same bar as 2.7): destroy clean, single procedure brings everything up, ArgoCD **auto**-reaches Synced/Healthy (no manual sync — this is the differentiator vs 2.7), health endpoint + DAG parse green. Capture real command output as evidence; no fabricated results.
- `terraform fmt`/`validate` + `pre-commit` for the module change.

### Previous Story Intelligence

- Branch is now `main` (2.7 merged the cutover). HEAD `8ad8f01`. Epic 2 done.
- **2.7 facts that drive this story:** (1) apps needed manual `kubectl patch ... operation sync` → no auto-sync today (the gap AC3 fixes); (2) `/etc/hosts` must be `127.0.0.1` (docker tunnel binds localhost); (3) the argocd provider needs the tunnel to reach `argocd.data:443`; (4) `data` ns was empty at 2.7 apply (so Bitnami first-init password took cleanly — a clean recreate keeps this true); (5) SimpleAuth admin password is ephemeral (retrieve from api-server logs for login).
- **Gotchas:** terraform-docs `<br>`→`<br/>` churn → revert after pre-commit. sudo can't prompt via Claude Code's `!` (use a real terminal or macOS `osascript ... with administrator privileges`).

### References

- [Source: docs/planning-artifacts/epics.md#Story 3.1] — clean apply → full platform + ArgoCD auto-reconcile.
- [Source: docs/planning-artifacts/architecture.md#D1 Rollout Sequencing, #D6 Terraform Shape] — recreate-from-clean is acceptable (local/disposable); reuse generic application module.
- [Source: docs/implementation-artifacts/2-7-deploy-and-verify-airflow-3-0-end-to-end.md] — the manual-sync gap, /etc/hosts 127.0.0.1, tunnel, ephemeral password.
- [Source: docs/implementation-artifacts/deferred-work.md] — 2.7 follow-ups + the docker/tunnel corrections.
- [Source: terraform/modules/k8s/argocd/application/01-application.tf] — the module to add syncPolicy to.
- [Source: docs/project-context.md] — TF conventions, doc/commit gotchas.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### Review Findings

### File List

## Change Log

| Date | Change |
|------|--------|
| 2026-06-21 | Story 3.1 created (ready-for-dev). Clean-state reproducibility test. Core deliverable: add `syncPolicy.automated` to the ArgoCD application module (2.7 proved apps don't self-reconcile). Confronts the argocd-provider bootstrap ordering + documents the host prerequisites (tunnel + /etc/hosts→127.0.0.1) and a reproducibility runbook. Destroy/recreate is live + gated on operator approval. |
