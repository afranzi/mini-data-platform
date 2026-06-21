---
baseline_commit: 3030aa174786be4815ea4d87e169bde05c8ffa3a
---

# Story 3.2: Resource-Footprint and Secret-Hygiene Verification

Status: done

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

- [x] **Task 1 — Footprint: scheduling + OOM (AC: 1)** — all 8 `data` pods `Running` (api-server, scheduler 2/2, dag-processor 3/3, triggerer 3/3, worker 2/2, redis, statsd, postgres); **0 Pending, 0 OOMKilled, 0 restarts**. Node `data`: allocatable 4 cpu / ~8Gi; allocated **requests 1906m cpu (47%) / 3020Mi mem (38%)**, limits 2 cpu (50%) / 2218Mi (27%). Stack fits the default `8g`/`4` — **minikube lever NOT raised**.
- [x] **Task 2 — Secret hygiene: repo scan (AC: 2)** — `git ls-files` has **no tfstate** (`.gitignore`: `*.tfstate`, `*.tfstate.*`); no `"data"` plaintext password in `12-airflow.tf`; no connection strings with embedded passwords (only `${random_password...}` interpolations); no hardcoded secret-value literals; no fernet-key-shaped strings in tracked files; `values.yaml` references secrets by **name only** (`*SecretName: airflow-*`). NFR3 holds repo-wide.
- [x] **Task 3 — Record + finalize (AC: 3)** — footprint + secret-scan evidence recorded below. No code change needed (clean result). No lever raise to document.

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

- ✅ **AC1 (NFR2/CM1)** — no Pending, no OOMKilled, 0 restarts across all 8 `data` pods. Node footprint: requests 47% cpu / 38% mem on the default `8g`/`4` node → comfortable headroom; the minikube `--cpus`/`--memory` lever was **not** raised.
- ✅ **AC2 (NFR3)** — repo-wide scan clean: no committed fernet key / api-secret / JWT / admin / postgres password; no embedded passwords in connection strings (interpolations only); no tfstate tracked (gitignored). Secret material lives only in local TF state + in-cluster k8s Secrets. `*SecretName:` lines are references (names), not values.
- ✅ **AC3** — evidence recorded here. No code change (clean verification); no lever raise to document.
- Confirms the NFR3 work from Stories 2.1/2.6 held across the whole repo, and the AR10 conservative sizing (Story 2.3) fits the local node.

### Review Findings

_Code review 2026-06-21 — **clean**. No-source verification story; the review adversarially re-checked completeness: the secret scan was broadened from `*.tf/*.yaml/*.py` to **all tracked files** (connection-string passwords, fernet-shape/long-token literals, the `fernet-key`/`api-secret-key`/`admin-password` key names) → still clean (only hit is `"admin-password" = random_password.admin.result`, a name→random-ref, value in state only). OOM gate confirmed robust (lastState + restartCount, all pods stable 45m since the 3.1 rebuild, no churn). All 3 ACs PASS; no findings._

### File List

- _(none — read-only verification; no source files changed. Evidence captured in this story's Dev Agent Record.)_

## Change Log

| Date | Change |
|------|--------|
| 2026-06-21 | Story 3.2 created (ready-for-dev). Read-only footprint (no Pending/OOM, node capacity) + secret-hygiene repo scan (no committed plaintext secrets; state gitignored). Non-destructive verification against the live 3.1 stack. |
| 2026-06-21 | Verified: footprint 47% cpu / 38% mem, no Pending/OOM (lever not raised); secret-hygiene scan clean repo-wide (NFR3 holds). No code change. Status → review. |
