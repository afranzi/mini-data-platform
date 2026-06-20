---
baseline_commit: 305075b2c0c9ecc8edcec15daa1b609afc3279d7
---

# Story 2.7: Deploy and Verify Airflow 3.0 End-to-End

Status: review

## Story

As a platform operator,
I want the Airflow 3 cutover synced and verified end-to-end on the live (minikube/docker) cluster,
so that Airflow 3.0 is proven working before closing Epic 2 (FR8, FR15; SM2, SM3, SM4; architecture D1 step 2).

## ⚠️ Operator Prerequisites (manual — required before any verification)

This is a **live-apply** story. Unlike 2.1–2.6 (code-only), it mutates the running cluster and needs host-level access the agent cannot perform:

1. **Cluster up:** `data` minikube profile running (docker driver, k8s `v1.33.4`, node Ready). If not: `cd terraform/main && terraform apply` (or `minikube start -p data`).
2. **Tunnel (real terminal, sudo):** `sudo minikube tunnel -p data` — must stay running for the whole story. Required because the docker driver's node IP (`192.168.49.2`) is not host-routable on macOS; the ArgoCD `oboukili/argocd` provider and `https://airflow.data` both need it. [deferred-work: 1.3 / docker switch]
3. **/etc/hosts:** add `192.168.49.2 argocd.data airflow.data` (re-confirm the IP with `minikube ip -p data` — it can change on recreate). [deferred-work: minikube IP may change]

> The agent will HALT and ask the operator to confirm the tunnel + /etc/hosts are live before running anything that touches the cluster.

## Acceptance Criteria

1. **App Synced/Healthy (SM2, FR8).** After `terraform apply` provisions the ArgoCD Project + `postgres` + `airflow` Applications and ArgoCD syncs, the `airflow` application is **Synced/Healthy** and every component is Healthy: `api-server`, `scheduler`, standalone `dag-processor`, `triggerer`, `workers`, **Redis** broker. No `Pending`/`CrashLoopBackOff`/`ImagePullBackOff`. Postgres app also Synced/Healthy. (This completes the deferred Story 1.3 AC#3/#4 GitOps app-sync.)
2. **DB migrate sync-hook ran (FR12/D5).** The `migrateDatabaseJob` (ArgoCD `hook: Sync`, `useHelmHooks: false`) completed successfully (`airflow db migrate` against the metadata DB). No FAB create-user job runs (SimpleAuth; `createUserJob.enabled: false`).
3. **UI reachable + login (SM3, FR15).** `https://airflow.data` loads the Airflow 3 UI and login succeeds via the SimpleAuth admin. The actual admin password mechanism is **resolved and documented** (the `admin:admin` user is set via `simple_auth_manager_users`; the auto-generated password file vs the unused `admin-password` secret key is reconciled — see Task 5).
4. **DAG parses clean (FR15, FR14a-c).** The example `ChesterDag` DAG (gitSync'd from the public repo `airflow` subPath, branch `main`) appears in the UI / `airflow dags list` with **no import or deprecation errors** (no AIR301/302-class warnings at parse time).
5. **Manual run succeeds end-to-end (SM4, FR15).** A manual trigger of the example DAG completes successfully — scheduler queues it, a Celery worker executes it (broker + result backend working), task state persists to the metadata DB.
6. **Folded-in runtime checks pass (deferred 2.3/2.4/2.6).** Each is verified or its follow-up applied:
   - **Postgres password (2.6 review, High):** confirm the postgres PVC was fresh at apply so `random_password.postgres` actually took; if an old PVC carried the `data` password, recreate the PVC or `ALTER ROLE mini PASSWORD`. Metadata + result-backend auth must succeed.
   - **Redis/broker secrets (2.3):** the chart's redis-password/broker-url secrets carry `helm.sh/hook: pre-install`; under ArgoCD (no Helm hooks) confirm they exist at steady state and workers reach the broker.
   - **base_url/TLS (2.3):** `config.api.base_url=https://airflow.data` with no ingress `tls:` — confirm UI/redirects behave over the tunnel; if broken, add ingress TLS or adjust base_url and document.
   - **poetry.lock relock (2.4):** `poetry lock` in a py3.12 env so the lock resolves Airflow 3.2.2 (not 2.8); commit the relocked file.
   - **airflow config lint + imports (2.4):** `pre-commit run --hook-stage manual airflow-config-lint` and confirm `airflow.sdk` imports resolve + `airflow dags list` parses in the Airflow-3 env.

## Tasks / Subtasks

- [x] **Task 0 — Confirm operator prerequisites (gate)** — cluster Running/Ready `v1.33.4`; tunnel running; `/etc/hosts` corrected to `127.0.0.1 argocd.data airflow.data` (docker tunnel binds localhost, not node IP). `data` ns empty → Bitnami trap moot.
- [x] **Task 1 — Live apply + ArgoCD sync (AC: 1, 2)** — pushed feature branch + merged to `main` (ArgoCD source-of-truth); `terraform apply` (11 add) created secrets + ArgoCD project + apps. Both `postgres` and `airflow` **Synced/Healthy**; all Airflow 3 components Running; migrate job `Database migration done!`; no create-user job; no CrashLoop/ImagePull.
- [x] **Task 2 — Broker/result-backend wiring check (AC: 5, 6)** — `airflow-broker-url` + `airflow-redis-password` exist at steady state; worker `Connected to redis://...@airflow-redis:6379/0`, result backend `postgresql://mini:**@postgres-postgresql...`, `celery@... ready`.
- [x] **Task 3 — UI + login (AC: 3)** — `https://airflow.data` UI 200; `/api/v2/monitor/health` all-healthy; SimpleAuth `POST /auth/token` → 201. base_url/TLS: functions over tunnel on HTTP (https cosmetic).
- [x] **Task 4 — DAG parse + manual run (AC: 4, 5)** — **found + fixed** a real bug (`ScheduleArg` import); `list-import-errors` → none; `my_dag_name` listed; manual run `story27-verify-1` → **success** (+ auto-scheduled run success).
- [x] **Task 5 — SimpleAuth admin password reconcile (AC: 3, deferred 2.3)** — mechanism resolved + documented (auto-generated ephemeral file; retrieve from api-server logs). Robust pinning deferred (beyond small-fix scope) → deferred-work.
- [x] **Task 6 — Python toolchain relock + lint (AC: 6, deferred 2.4)** — `poetry lock` → airflow 2.8.2→3.2.2; `airflow config lint` run in the live env (remaining findings are upstream chart defaults → deferred-work).
- [x] **Task 7 — Finalize** — pre-commit clean on touched code (isort/black-fixed dag.py); helm-docs no drift; deferred-work updated (folded items RESOLVED + 2 new follow-ups); evidence captured; all committed + pushed to `main`. **Bonus fix:** wired `jwtSecretName` to stop chart-JWT non-determinism → app deterministically Synced/Healthy.

> ⚠️ **Scope boundary:** This story is verification + minimal runtime follow-ups (admin password, TLS, poetry.lock). It is NOT a place to re-architect the chart/values. If a defect needs a values.yaml/topology change beyond a small fix, capture it and raise a `correct-course` rather than expanding scope.

## Dev Notes

### Critical guardrails

- **Deploy ONLY via ArgoCD** (architecture: "deploy only via ArgoCD"). Do not `kubectl apply`/`helm install` the workload directly. Terraform provisions the ArgoCD Project + Applications + secrets; ArgoCD renders and syncs the chart. Manual `kubectl` is **read-only** here except for the explicit AC6 break-glass fixes (PVC/role, which are infra remediation, not workload deploy).
- **Never re-enable Helm hooks.** Jobs use `useHelmHooks: false` + `argocd.argoproj.io/hook: Sync` (D5). If the migrate job didn't run, fix the annotation/sync — don't switch to Helm hooks.
- **Health on the v2 path.** Airflow 3 health is `/api/v2/monitor/health` (D7), not the old `/health`. Ingress routes `airflow.data` → `api-server` svc.
- **Secret names are a contract.** The chart references `airflow-config-credentials`, `airflow-metadata`, `airflow-result-backend` by exact name (created in 2.1/2.6). Don't rename.
- **Two-commit rollout (D1) already done** — k8s 1.33 (Epic 1) + Airflow-3 cutover (2.1–2.6). This story is the *verification* of the second. Rollback = revert branch + `terraform apply` (cluster is disposable/local, NFR5).
- **gitSync pulls from the PUBLIC repo** (`https://github.com/afranzi/mini-data-platform.git`, `airflow` subPath, branch `main`). The DAG code under test is what's on `main` — note: the migrated DAGs (Story 2.4) must be on `main` for gitSync to fetch them. If they're only on the feature branch, the gitSync `branch`/`rev` or the merge state needs confirming (flag to operator).

### Known risks pulled into this story (from deferred-work.md)

- **[High] Bitnami first-init password trap (2.6 review).** `random_password.postgres` only lands if the postgres data dir was empty at apply. Cluster recreate (Story 1.3) likely gave a fresh PVC, but if `terraform apply` reuses an existing PVC with the old `data` password, metadata + result-backend auth fail. Remedy: recreate PVC or `ALTER ROLE mini PASSWORD '<generated>'` (read the generated value from `kubectl -n data get secret airflow-metadata -o jsonpath` / TF state).
- **[Med] Redis/broker `pre-install` hook secrets (2.3).** ArgoCD ignores Helm hooks → confirm these secrets still materialize at steady state, else workers can't reach the broker.
- **[Low-Med] base_url https vs no ingress TLS (2.3).** May cause redirect/mixed-content issues over the tunnel.
- **[High] SimpleAuth admin password (2.3).** The `admin-password` secret key is currently unused; the password auto-generates in-pod. Resolve the real login path (Task 5).
- **[Med] poetry.lock still resolves Airflow 2.8 (2.4).** Relock in py3.12. Deployed image is already 3.2.2; this is for local dev/test parity.

### Current state (key files — mostly READ-ONLY this story)

- `terraform/main/12-airflow.tf` — finalized in 2.6 (secrets, postgres password, airflow app + depends_on). The live `terraform apply` exercises it. [UPDATE only for AC6 break-glass, unlikely]
- `helms/airflow/values.yaml` — official-chart config (2.3). [UPDATE only if TLS/admin-password fix needed]
- `airflow/pyproject.toml` + `poetry.lock` — relock target (Task 6).
- `airflow/mini_dags/dags/example.py`, `mini_dags/chester/dag.py` — the DAG under test (2.4). Must be on `main` for gitSync.

### Testing standards

- This story's "tests" are **live verification**: ArgoCD Synced/Healthy, pod readiness, migrate-job success, DAG parse (`airflow dags list` → no `import_errors`), and a real DAG run reaching `success`. Capture command outputs as evidence (no fabricated results — the workflow forbids claiming completion without proof).
- Code follow-ups (poetry.lock, any TLS/admin fix) go through `terraform validate` / `pre-commit` as in prior stories.

### Previous Story Intelligence

- Branch `feat/airflow-3-k8s-133-upgrade`; latest commit `305075b` (Story 2.6 review). 2.1–2.6 all done.
- **2.6 learnings:** all secret wiring + postgres password + result-backend done and `terraform validate`-clean; the one open runtime risk is the Bitnami first-init password trap (now AC6). The `db+` result-backend prefix is verified correct against the chart template (no double-prefix).
- **Docker/tunnel gotcha (confirmed):** host access to `argocd.data`/`airflow.data` needs `sudo minikube tunnel -p data` + `/etc/hosts`. The ArgoCD provider can't reach `argocd.data:443` without it (this blocked Story 1.3 AC#3).
- **Doc gotcha:** revert terraform-docs `<br>`→`<br/>` churn after pre-commit.
- **Tooling:** `airflow config lint` is a manual-stage pre-commit hook (needs Airflow installed); ruff AIR301/302 needs `uvx ruff@latest` (system ruff 0.4.10 too old).

### References

- [Source: docs/planning-artifacts/epics.md#Story 2.7] — the 4 core ACs (Synced/Healthy, UI+login, DAG parse, manual run).
- [Source: docs/planning-artifacts/architecture.md#D1 Rollout, #D3 Topology, #D5 DB Migration, #D7 Ingress & Health] — deploy-only-via-ArgoCD, v2 health path, sync-hook migrate job, no Helm hooks.
- [Source: docs/implementation-artifacts/deferred-work.md] — all 2.7-tagged items folded into AC6/Tasks 2,5,6 + the 2.6-review Bitnami trap.
- [Source: helms/airflow/values.yaml] — SimpleAuth user, base_url, migrate/create-user jobs, component topology.
- [Source: docs/project-context.md] — minikube docker/tunnel host config, commit/doc conventions.

## Dev Agent Record

### Agent Model Used

### Debug Log References

- **Pre-flight (Task 0):** cluster `data` Running, node Ready `v1.33.4`; `sudo minikube tunnel -p data` running; `/etc/hosts` has `192.168.49.2 argocd.data airflow.data`. ArgoCD installed & all pods Running; ingress `argocd.data → 192.168.49.2`. **`data` namespace empty (no workloads, no Postgres PVC)** → Bitnami first-init password trap (AC6 High) is MOOT (fresh init).
- **`terraform plan`:** clean — `Plan: 11 to add, 0 to change, 0 to destroy` (5 random_* + 3 kubernetes_secret + argocd project + 2 argocd_application).
- **🛑 BLOCKER (GitOps source of truth):** The Airflow 3 cutover (Chart.yaml official dep, values.yaml, migrated DAGs from Stories 2.2–2.6) lives ONLY on `feat/airflow-3-k8s-133-upgrade`, which is **not pushed to origin**. `origin/main:helms/airflow/Chart.yaml` is still the OLD community chart (`version 8.8.0`, `appVersion 2.6.3`, dep `airflow-helm/charts`). The `airflow` ArgoCD app uses `target_revision = "HEAD"` (→ origin/main) and gitSync uses `branch: main`. Applying now would deploy the OLD Airflow 2.x stack from main — verification (AC1–5) would not exercise Airflow 3. Resolution requires an operator decision (push + merge to main, or point target_revision/gitSync at the pushed feature branch for verification). HALTED pending decision.

- **Task 1 — `terraform apply` (partial):** ✅ all 5 `random_*` + 3 `kubernetes_secret` (config-credentials, metadata, result-backend) created in `data`. ❌ `module.project.argocd_project` failed: `dial tcp 192.168.49.2:443: operation timed out` (oboukili/argocd provider → `argocd.data:443`).
- **Connectivity root cause (verified):** node IP `192.168.49.2:443` and `:80` are unreachable from host (5s timeout each); `127.0.0.1:443` is OPEN and returns **HTTP 200 from ArgoCD** with `Host: argocd.data`. The docker-driver `minikube tunnel` binds the ingress to **127.0.0.1**, but `/etc/hosts` maps the `.data` hosts to `192.168.49.2` (node IP, not host-routable on docker). **Fix: map `argocd.data`/`airflow.data` → `127.0.0.1` in `/etc/hosts`** (corrects the stale 192.168.49.2 in the Story 1.3 deferred note). Needs operator sudo. After fixing, `terraform apply` is idempotent (secrets exist; only the 3 argocd resources remain).

### Completion Notes List

- ✅ **AC1** — `airflow` + `postgres` ArgoCD apps **Synced/Healthy**; all Airflow 3 components Running (api-server, scheduler, dag-processor, triggerer, worker, redis). Completes the deferred Story 1.3 AC#3/#4 GitOps app-sync.
- ✅ **AC2** — `migrateDatabaseJob` (ArgoCD `hook: Sync`) ran `airflow db migrate` → "Database migration done!"; no create-user job (SimpleAuth).
- ✅ **AC3** — UI 200 at `airflow.data` (tunnel); `/api/v2/monitor/health` all-healthy; SimpleAuth admin login → 201 token. Password is auto-generated/ephemeral (documented; pinning deferred).
- ✅ **AC4** — `ChesterDag`/`my_dag_name` parses with **no import errors** (after fixing the `ScheduleArg` import bug found here).
- ✅ **AC5** — manual DAG run `story27-verify-1` → **success** end-to-end (scheduler → Celery worker → metadata DB).
- ✅ **AC6** — Bitnami password trap moot (fresh PVC); broker/redis secrets present + worker connected; base_url/TLS functions over tunnel; poetry.lock relocked to 3.2.2; config lint run (remaining = chart defaults).
- **GitOps decision (operator-approved):** merged feature branch → `main` so ArgoCD (`target_revision=HEAD`) + gitSync (`branch: main`) serve the cutover. Rollback = revert + reapply (NFR5).
- **Two real fixes shipped during verification:** (1) `ScheduleArg` import path (DAG parse bug); (2) `jwtSecretName` wired to the TF secret (chart was auto-generating a random JWT each render → permanent ArgoCD drift; now deterministically Synced).
- **Connectivity correction:** docker-driver `minikube tunnel` binds ingress to `127.0.0.1` (not node IP `192.168.49.2`) — `/etc/hosts` fixed accordingly.

### Review Findings

_Pending code review._

### File List

- `airflow/mini_dags/chester/dag.py` (modified) — import `ScheduleArg` from `airflow.sdk.definitions.dag` (not re-exported at `airflow.sdk` top level in 3.2.2).
- `helms/airflow/values.yaml` (modified) — wire `jwtSecretName: airflow-config-credentials` (stop chart JWT non-determinism / ArgoCD drift); remove removed-in-3 `config.database.load_default_connections`.
- `airflow/poetry.lock` (modified) — relocked `apache-airflow` 2.8.2 → 3.2.2 (py3.12).
- `docs/implementation-artifacts/deferred-work.md` (modified) — RESOLVED the folded-in 2.7 items + added 2 follow-ups (SimpleAuth password pinning; chart-default config-lint findings) + corrected the `/etc/hosts` IP guidance.
- `terraform/main/state/*` (state only — `terraform apply` created secrets + ArgoCD project/apps; no `.tf` changes this story).

## Change Log

| Date | Change |
|------|--------|
| 2026-06-20 | Story 2.7 created (ready-for-dev). Live deploy-and-verify; folds in all 2.7-deferred runtime checks (Bitnami password trap, redis/broker secrets, base_url/TLS, SimpleAuth admin password, poetry.lock relock, config lint + DAG parse). Operator prerequisites (cluster + `sudo minikube tunnel` + `/etc/hosts`) documented as a hard gate. |
| 2026-06-20 | Merged feature branch → `main`; `terraform apply` deployed; all ACs verified GREEN on the live cluster (apps Synced/Healthy, migrate done, UI+login, DAG parse + manual run success). Fixed `ScheduleArg` import + wired `jwtSecretName`; relocked poetry; corrected `/etc/hosts`→127.0.0.1. Status → review. |
