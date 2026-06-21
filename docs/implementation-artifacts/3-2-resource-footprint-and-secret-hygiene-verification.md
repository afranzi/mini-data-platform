---
baseline_commit: 3030aa174786be4815ea4d87e169bde05c8ffa3a
---

# Story 3.2: Resource-Footprint and Secret-Hygiene Verification

Status: ready-for-dev

## Story

As a platform operator,
I want the running footprint and the repository's secret hygiene verified,
so that the upgrade respects local resource limits and commits no secrets (NFR2, NFR3, CM1).

## Acceptance Criteria

1. **No unschedulable / OOM pods (NFR2, CM1).** On the fully-synced Airflow 3 stack (`data` namespace), no pod is `Pending` (unschedulable) and none has been `OOMKilled` (no restarts with `reason: OOMKilled`). If the node couldn't fit the stack and the minikube `--cpus`/`--memory` lever was raised, that adjustment is **documented as applied** (D10/CM1). Capture node allocatable vs requests as evidence.
2. **No committed plaintext secrets (NFR3).** A scan of the repository confirms **no fernet key, `[api] secret_key`, JWT secret, admin password, or Postgres password is committed in plaintext** anywhere in tracked files. The only secret *material* lives in Terraform state (local, gitignored) and in-cluster k8s Secrets — never in `.tf`, `values.yaml`, DAGs, or docs. Secret **names/references** (e.g. `fernetKeySecretName: airflow-config-credentials`) are fine; secret **values** are not.
3. **Findings recorded (NFR2/NFR3).** Footprint numbers + the secret-scan result are recorded (Dev Agent Record / a short note), so the gates are auditable.

> ⚠️ **Scope boundary:** read-only **verification** of the running stack + a repo scan. No teardown, no chart/topology changes. If a real over-commit or a committed secret is found, fix the minimal cause (raise the minikube lever / remove the secret + rotate) — but a clean result needs no code change.

## Tasks / Subtasks

- [ ] **Task 1 — Footprint: scheduling + OOM (AC: 1)**
  - [ ] `kubectl --context data -n data get pods` — confirm all `Running`/`Completed`, **none `Pending`**. For any `Pending`, `kubectl describe` to check for `FailedScheduling` (insufficient cpu/memory).
  - [ ] Check for OOM: `kubectl --context data -n data get pods -o json` → scan `status.containerStatuses[*].lastState.terminated.reason` and `restartCount` for `OOMKilled` / nonzero restarts.
  - [ ] Capture node capacity vs usage: `kubectl --context data describe node data` (Allocatable + Allocated resources / requests) and, if metrics-server is up, `kubectl top pods -n data` / `kubectl top node`.
  - [ ] Note whether the minikube `--cpus`/`--memory` default (`modules/k8s/minicluster/00-variables.tf`, currently `8g`/`4`) was sufficient or had to be raised. If raised, document the value applied (CM1 lever).
- [ ] **Task 2 — Secret hygiene: repo scan (AC: 2)**
  - [ ] Scan tracked files for **secret values** (not names): grep the working tree + check that `terraform/main/state/` is gitignored. Look for fernet-key-shaped strings (44-char base64), long random tokens, `password = "..."` literals, `admin:<password>`, connection strings with embedded passwords.
  - [ ] Confirm `git ls-files` does NOT include `terraform/main/state/terraform.tfstate*` (state holds the real secret values; it must be gitignored). Check `.gitignore`.
  - [ ] Confirm `values.yaml` / `12-airflow.tf` reference secrets by **name only** (no inline values) — cross-check the NFR3 work from Stories 2.1/2.6 held (no `"data"` plaintext, randoms in TF only).
  - [ ] Optionally run `detect-secrets`/`gitleaks` over tracked files if available; triage any hits (the `*SecretName` keyword false-positives are expected — they're names, not values).
- [ ] **Task 3 — Record + finalize (AC: 3)**
  - [ ] Record footprint numbers + secret-scan result in the Dev Agent Record. If the minikube lever was raised, note it in the runbook/deferred-work.
  - [ ] No code expected; if a fix was needed, run `pre-commit` + revert unrelated doc churn. Commit any notes with the `Co-Authored-By` line.

## Dev Notes

### Critical guardrails

- **Read-only verification.** This story inspects; it does not mutate the cluster or chart. The stack is already up (Story 3.1 rebuild — apps Synced/Healthy). Use `kubectl --context data` read commands.
- **Secret names vs values.** NFR3 forbids committed secret **values**, not references. `fernetKeySecretName: airflow-config-credentials` (a name) is correct and expected; a fernet key string or `auth.password = "<actual>"` would be a violation. Stories 2.1/2.6 moved all secret material to `random_*` in TF state + k8s Secrets and removed the `"data"` plaintext — this story confirms that held across the repo.
- **Where real secrets legitimately live:** `terraform/main/state/terraform.tfstate` (local backend, must be gitignored) and in-cluster k8s Secrets (`airflow-config-credentials`, `airflow-metadata`, `airflow-result-backend`, chart-generated redis/broker). None of these are committed.
- **Footprint context (D10/CM1):** conservative per-component requests/limits were set in `values.yaml` (Story 2.3, AR10). The minikube node is `8g`/`4 cpu` by default (`modules/k8s/minicluster/00-variables.tf`). The whole Airflow 3 stack (api-server, scheduler, dag-processor, triggerer, worker, redis, statsd) + Postgres must fit. The 3.1 rebuild already ran them all `Running` — this story formalizes the no-Pending/no-OOM gate with evidence.
- **metrics-server** may or may not be enabled; `kubectl top` needs it. If absent, use `describe node` (requests/allocatable) — that's sufficient for the scheduling gate (Pending is request-driven, not usage-driven).

### Current state (no files expected to change)

- `helms/airflow/values.yaml` — per-component `resources.requests/limits` (Story 2.3). READ for the footprint baseline; do not edit unless a real OOM/Pending forces a sizing fix.
- `terraform/modules/k8s/minicluster/00-variables.tf` — `memory`/`cpus` defaults (`8g`/`4`). READ; raise only if the node can't fit the stack (CM1 lever) — and document if so.
- `terraform/main/12-airflow.tf` + `helms/airflow/values.yaml` — confirm secret references are name-only (NFR3). READ.
- `.gitignore` — confirm `terraform/main/state/` (or `*.tfstate`) is ignored.

### Testing standards

- Verification story: evidence = real `kubectl` output (pod phases, OOM scan, node allocatable) + the repo secret-scan result. No fabricated results. No unit tests.
- If a fix is made (lever raise / secret removal), `terraform validate` / `pre-commit` as applicable.

### Previous Story Intelligence

- On `main`; HEAD `3030aa1`. Epic 3: 3.1 done, **3.3 DESCOPED** (operator decision — old-version rollback not needed). After 3.2, only 3.4 (docs) remains.
- **3.1 rebuild facts:** the full Airflow 3 stack + Postgres came up all `Running` on the default `8g`/`4` node with no Pending/OOM observed — so AC1 is expected to pass without raising the lever (confirm with evidence). Components: api-server, scheduler, standalone dag-processor, triggerer, worker, redis, statsd, postgres.
- **NFR3 history:** Story 2.1 generated `random_*` secrets (TF state only); Story 2.6 removed the last `"data"` plaintext password + reconciled to `random_password.postgres`. Story 2.7/3.1 verified no plaintext in `12-airflow.tf`. This story confirms repo-wide.
- **detect-secrets noise:** the helms `detect-secrets` hook flags `values.yaml` `*SecretName:` lines — these are **names** (false positives), not values. Expected; not an NFR3 violation.

### References

- [Source: docs/planning-artifacts/epics.md#Story 3.2] — no Pending/OOMKilled; minikube lever documented; repo secret scan.
- [Source: docs/planning-artifacts/architecture.md#D10 Resource Sizing, #NFR2, #NFR3, CM1] — conservative sizing, footprint lever, no committed secrets.
- [Source: helms/airflow/values.yaml] — per-component resources.
- [Source: terraform/modules/k8s/minicluster/00-variables.tf] — node memory/cpus lever.
- [Source: terraform/main/12-airflow.tf] — TF-managed secrets (names referenced, values in state only).
- [Source: docs/implementation-artifacts/deferred-work.md] — NFR3 history (2.1/2.6).

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### Review Findings

### File List

## Change Log

| Date | Change |
|------|--------|
| 2026-06-21 | Story 3.2 created (ready-for-dev). Read-only footprint (no Pending/OOM, node capacity) + secret-hygiene repo scan (no committed plaintext secrets; state gitignored). Non-destructive verification against the live 3.1 stack. |
