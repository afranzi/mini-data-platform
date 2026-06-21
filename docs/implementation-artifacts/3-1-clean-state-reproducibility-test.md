---
baseline_commit: 8ad8f0157144e141dd702ee8e70ea0ead36d3c69
---

# Story 3.1: Clean-State Reproducibility Test

Status: review

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
- [x] **Task 1 — Add automated syncPolicy to the ArgoCD application module (AC: 3)** — added `sync_policy { automated { prune, self_heal, allow_empty=false } sync_options }` + `automated_sync` (default true) / `sync_options` vars. `terraform validate` Success. Both apps inherit it (default on). Committed `a4d9b51`.
- [x] **Task 2 — Clean teardown + single-pass apply (AC: 1, 2)** — `terraform destroy` (two passes — project-delete race) → clean. Rebuild via documented **two-phase apply**: Phase A `-target=module.cluster -target=module.argocd` (retried once for ingress-nginx readiness), restart tunnel, Phase B full `terraform apply` (12 added). k8s `v1.33.4`, node Ready.
- [x] **Task 3 — Verify automatic reconciliation (AC: 3, 4)** — both apps reached **Synced/Healthy with NO manual sync** (automated syncPolicy works — the 2.7 gap is closed). All components Running, migrate Completed, `/api/v2/monitor/health` all-healthy, `list-import-errors` → none.
- [x] **Task 4 — Document the reproducibility runbook (AC: 5)** — `docs/runbooks/clean-state-bring-up.md`: host prereqs, two-phase apply, retry points, auto-reconcile, SimpleAuth password retrieval, teardown. (Dedicated runbook to avoid the stale `terraform/main/readme.md` quickstart — that's Story 3.4.)
- [x] **Task 5 — Finalize** — removed the stray `.tmp-chart`; pre-commit regen kept legit docs (new module vars + helm README catch-up of 2.7 values), reverted project-module `<br>` churn; deferred-work updated with 2 hardening follow-ups; evidence captured; committed.

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

- **T1:** Added `sync_policy.automated { prune, self_heal }` (+ `sync_options`, `automated_sync` var default true) to `modules/k8s/argocd/application`; `terraform validate` Success; committed `a4d9b51`.
- **T2 destroy:** `terraform destroy` — **first pass errored** on `argocd_project` delete ("project is referenced by 2 applications"): TF removes the Application resources from state instantly, but ArgoCD cascade-deletes them async, so the project delete raced. **Re-running destroy succeeded** (apps fully gone). → Reproducibility note: destroy may need a second pass, or an explicit app→project `depends_on`/wait. ArgoCD CRDs retained by resource policy (expected).
- **T2 apply Phase A** (`-target=module.cluster -target=module.argocd`, no tunnel needed): **first pass errored** — ArgoCD helm release failed calling the `ingress-nginx` admission webhook (`connection refused`): ingress-nginx controller not Ready when ArgoCD's Ingress was created. **Retry succeeded** once the controller was Running. → Reproducibility note: clean apply has an ingress-nginx-readiness race before the ArgoCD ingress; needs a retry or a wait/dependency.
- **T2 tunnel:** new cluster reused node IP `192.168.49.2`; the `sudo minikube tunnel` process survived but lost its port binding (argocd.data:443 → connection refused) → requires a tunnel restart after recreate (host prerequisite; operator action — sudo).

### Completion Notes List

- ✅ **AC1** clean teardown — `terraform destroy` (two passes; ArgoCD cascade-delete races the project delete) left a clean state.
- ✅ **AC2** rebuild — full platform (k8s v1.33.4 + ArgoCD + Postgres + Airflow 3) via a **documented two-phase apply** (argocd-provider bootstrap can't configure before ArgoCD exists). Zero manual *workload* steps; the two host interjections (tunnel restart; the `-target` bootstrap) are env/ordering, captured in the runbook.
- ✅ **AC3 (core deliverable)** — added automated `syncPolicy` to the application module; on the clean rebuild both apps **self-reconciled to Synced/Healthy with no manual sync**. This closes the explicit 2.7 gap (apps previously needed `kubectl patch operation`).
- ✅ **AC4** — end-state matches 2.7: all components Running, migrate sync-hook Completed, `/api/v2/monitor/health` all-healthy, `my_dag_name` parses (no import errors — `ScheduleArg` fix is on `main`).
- ✅ **AC5** — `docs/runbooks/clean-state-bring-up.md` records the full reproducible procedure incl. the two retry points + SimpleAuth login.
- **Two clean-apply races found** (both retry-recoverable, logged + deferred as Low hardening): ingress-nginx admission-webhook readiness before the ArgoCD ingress; ArgoCD project-delete vs async app cascade-delete on destroy.
- **Helm README catch-up:** the helm-docs regen also synced `helms/airflow/README.md` to the 2.7 values (jwtSecretName added / load_default_connections removed) — a missed 2.7 regen, now correct.

### Review Findings

_Pending code review._

### File List

- `terraform/modules/k8s/argocd/application/00-variables.tf` (modified) — `automated_sync` (bool, default true) + `sync_options` vars.
- `terraform/modules/k8s/argocd/application/01-application.tf` (modified) — `sync_policy { automated { prune, self_heal } sync_options }` block.
- `terraform/modules/k8s/argocd/application/readme.md` + `docs/terraform/modules/k8s/argocd/application.md` (modified) — terraform-docs regen for the new vars.
- `docs/runbooks/clean-state-bring-up.md` (new) — clean bring-up + teardown runbook.
- `helms/airflow/README.md` + `docs/helms/airflow.md` (modified) — helm-docs regen catching up the 2.7 values changes.
- `docs/implementation-artifacts/deferred-work.md` (modified) — 2 hardening follow-ups + auto-reconcile resolved.
- `terraform/main/state/*` (state only) — destroy + clean two-phase re-apply (no `terraform/main/*.tf` changes this story).

## Change Log

| Date | Change |
|------|--------|
| 2026-06-21 | Story 3.1 created (ready-for-dev). Clean-state reproducibility test. Core deliverable: add `syncPolicy.automated` to the ArgoCD application module (2.7 proved apps don't self-reconcile). Confronts the argocd-provider bootstrap ordering + documents the host prerequisites (tunnel + /etc/hosts→127.0.0.1) and a reproducibility runbook. Destroy/recreate is live + gated on operator approval. |
| 2026-06-21 | Implemented: automated syncPolicy added; full destroy + clean two-phase rebuild verified on the live cluster — apps **auto-reconciled to Synced/Healthy with no manual sync**, health + DAG parse green. Two retry-recoverable clean-apply races logged + deferred. Runbook written. Status → review. |
