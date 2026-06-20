---
baseline_commit: 305075b2c0c9ecc8edcec15daa1b609afc3279d7
---

# Story 2.7: Deploy and Verify Airflow 3.0 End-to-End

Status: ready-for-dev

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

- [ ] **Task 0 — Confirm operator prerequisites (gate)**
  - [ ] HALT and confirm with the operator: cluster up, `sudo minikube tunnel -p data` running, `/etc/hosts` has `192.168.49.2 argocd.data airflow.data` (IP re-confirmed via `minikube ip -p data`). Do not proceed until confirmed.
  - [ ] Pre-flight (read-only): `kubectl --context data get nodes` (Ready, `v1.33.4`), `kubectl get ns data argocd`.
- [ ] **Task 1 — Live apply + ArgoCD sync (AC: 1, 2)**
  - [ ] `cd terraform/main && terraform plan` — review (expect the new `airflow-result-backend` secret, postgres password change, airflow app values/depends_on from 2.6). Then `terraform apply`.
  - [ ] Watch ArgoCD: `kubectl -n argocd get applications` (or `argocd app get airflow` / UI at `https://argocd.data`). Wait for `postgres` then `airflow` → Synced/Healthy. If Postgres password mismatch (AC6 Bitnami trap) blocks metadata auth, fix the PVC/role and re-sync.
  - [ ] Confirm `migrateDatabaseJob` pod completed (`kubectl -n data get jobs,pods | grep -i migrate`; logs show `db migrate` success). Confirm no `create-user` job.
  - [ ] `kubectl -n data get pods` — all components Running/Ready, Redis up, no CrashLoop/ImagePull errors. Capture output for the Dev record.
- [ ] **Task 2 — Broker/result-backend wiring check (AC: 5, 6)**
  - [ ] Confirm the chart's redis/broker secrets exist at steady state (`kubectl -n data get secret | grep -i 'redis\|broker'`) despite the `pre-install` hook annotation (ArgoCD ignores Helm hooks). Worker logs show successful broker connect.
  - [ ] Confirm the `airflow-result-backend` secret is mounted and the result backend connects (no Celery result-backend errors in worker/scheduler logs).
- [ ] **Task 3 — UI + login (AC: 3)**
  - [ ] Browse `https://airflow.data` (tunnel up). Resolve base_url/TLS behavior (AC6): if redirects/UI break with no ingress `tls:`, add TLS to the ingress or adjust `base_url`, commit, re-sync, document the decision.
  - [ ] Determine the live SimpleAuth admin password (Task 5) and verify login.
- [ ] **Task 4 — DAG parse + manual run (AC: 4, 5)**
  - [ ] Confirm gitSync pulled the `airflow` subPath; `ChesterDag` example appears with no import/deprecation errors (`kubectl -n data exec <scheduler|dag-processor> -- airflow dags list` and check `import_errors`).
  - [ ] Trigger the example DAG (UI or `airflow dags trigger`); confirm a worker runs it and the run reaches `success`. Capture run/task state evidence.
- [ ] **Task 5 — SimpleAuth admin password reconcile (AC: 3, deferred 2.3)**
  - [ ] Inspect how Airflow 3 SimpleAuthManager assigns the `admin` password: it auto-generates to a file in the pod (the `admin-password` key in `airflow-config-credentials` is currently **unused**). Either (a) retrieve the generated password from the pod for login, or (b) wire a fixed password from the TF secret via the documented 3.2 env mechanism (`AIRFLOW__...` / SimpleAuth env) and re-sync. Pick one, implement if (b), and document the login procedure in the Dev record. [OQ4/AR12]
- [ ] **Task 6 — Python toolchain relock + lint (AC: 6, deferred 2.4)**
  - [ ] In a py3.12 env: `cd airflow && poetry lock` (relock to Airflow 3.2.2). Commit the relocked `poetry.lock`.
  - [ ] `pre-commit run --hook-stage manual airflow-config-lint` (needs Airflow installed); confirm `airflow.sdk` imports resolve and `airflow dags list` parses with no errors. Record results.
- [ ] **Task 7 — Finalize**
  - [ ] Run `pre-commit` for any code touched (TLS/admin-password/poetry.lock); revert unrelated argocd `<br>`→`<br/>` doc churn (known gotcha).
  - [ ] Update `deferred-work.md`: mark all folded-in 2.7 items RESOLVED (or re-defer with reason if genuinely out of reach).
  - [ ] Capture verification evidence (kubectl outputs, DAG run id/state, login proof) in the Dev Agent Record. Commit any code with the `Co-Authored-By` line.

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

### Completion Notes List

### Review Findings

### File List

## Change Log

| Date | Change |
|------|--------|
| 2026-06-20 | Story 2.7 created (ready-for-dev). Live deploy-and-verify; folds in all 2.7-deferred runtime checks (Bitnami password trap, redis/broker secrets, base_url/TLS, SimpleAuth admin password, poetry.lock relock, config lint + DAG parse). Operator prerequisites (cluster + `sudo minikube tunnel` + `/etc/hosts`) documented as a hard gate. |
