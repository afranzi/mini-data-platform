---
baseline_commit: 3373dde862296d0ab1b1190b4b607f557154cc51
---

# Story 2.6: Update Terraform ArgoCD Application and Wiring

Status: review

## Story

As a platform operator,
I want `terraform/main/12-airflow.tf` updated to deploy the new official Airflow chart via the existing generic application module — with the result-backend secret created, the Postgres password reconciled, the values nesting fixed, and secret-before-sync ordering enforced,
so that `terraform apply` provisions the Airflow 3 cutover cleanly with no drift and no committed plaintext (FR19, FR20, FR21, AR6, NFR3, D6).

## Acceptance Criteria

1. **`airflow-result-backend` Secret created (deferred from 2.3).** A new `kubernetes_secret "airflow_result_backend"` in `12-airflow.tf` (namespace `data`) with key `connection` =
   `db+postgresql://mini:${random_password.postgres.result}@postgres-postgresql.data.svc.cluster.local:5432/mini_data_platform`.
   Note the `db+` prefix (Celery result backend), distinct from the metadata secret's bare `postgresql://`. `values.yaml` already sets `data.resultBackendSecretName: airflow-result-backend`.
2. **Postgres password reconciled — plaintext removed (completes NFR3, deferred from 2.1).** `module.application_db` `parameters["auth.password"]` and the airflow app's `DATA_PASSWORD` plaintext `"data"` are both replaced by `random_password.postgres.result`. After this story, no `"data"` plaintext password literal remains in `12-airflow.tf`. The DB password (`application_db`), the metadata `connection`, and the result-backend `connection` all derive from the **same** `random_password.postgres.result` (no mismatch).
3. **`module.application` values nesting fixed (deferred from 2.3).** The community double-nesting `values.airflow.airflow.extraEnv` is corrected. The vestigial `DATA_DB`/`DATA_USER`/`DATA_PASSWORD` env (no consumer in repo) is removed — `module.application` carries no `values` block, or a single-level `airflow.*` block if one is genuinely needed.
4. **`depends_on` ordering enforced (deferred from 2.1).** `module.application` (airflow) declares `depends_on` on the three referenced secret resources: `kubernetes_secret.airflow_config_credentials`, `kubernetes_secret.airflow_metadata`, `kubernetes_secret.airflow_result_backend` — so the secrets exist before ArgoCD syncs the chart.
5. **Airflow application path/values/parameters valid for the official chart (D6, FR19/FR20).** `module.application` keeps `repo_url = local.airflow_helm_repo`, `path = "helms/airflow"` (the wrapper chart that now depends on the official Apache chart per Story 2.2), `target_revision = "HEAD"`, default `value_files = ["values.yaml"]`. The reused generic `modules/k8s/argocd/application` module is **not** replaced.
6. **`terraform fmt` + `terraform validate` pass with no unexpected drift.** (Live `terraform apply` + ArgoCD sync/health is **Story 2.7** — not this story.)

> ⚠️ **Scope boundary — code-only.** `terraform validate` is the gate. **No live `terraform apply`, no ArgoCD sync, no cluster mutation.** Runtime verification (apps Synced/Healthy, secrets applied at steady state, broker reachability, base_url/TLS, SimpleAuth login) is **Story 2.7**.

## Tasks / Subtasks

- [x] **Task 1 — Create the `airflow-result-backend` Secret (AC: 1)**
  - [x] In `terraform/main/12-airflow.tf`, add `resource "kubernetes_secret" "airflow_result_backend"` in `module.namespace.name` (`data`), `type = "Opaque"`, key `connection` = the `db+postgresql://...` URL above. Mirror the existing `kubernetes_secret.airflow_metadata` block (same user/host/db/port), differing only by the `db+` prefix.
  - [x] Place it adjacent to `kubernetes_secret.airflow_metadata` (the D4 secrets cluster), preserving the existing header comment style.
- [x] **Task 2 — Reconcile the Postgres password / remove plaintext (AC: 2)**
  - [x] In `module.application_db.parameters`, change `"auth.password" : "data"` → `"auth.password" : random_password.postgres.result`.
  - [x] Confirm `kubernetes_secret.airflow_metadata.connection` already uses `random_password.postgres.result` (it does — unchanged) and that the new result-backend secret uses the same. All three now share one password source.
  - [x] Verify no `"data"` plaintext password literal survives in the file (the DB *name* `mini_data_platform` and username `mini` are fine — only the password literal must go).
- [x] **Task 3 — Fix `module.application` values nesting + drop vestigial env (AC: 3)**
  - [x] Remove the double-nested `values.airflow.airflow.extraEnv` block. Repo grep confirms `DATA_DB`/`DATA_USER`/`DATA_PASSWORD` have **no consumer** (no DAG, chart, or config reads them) → delete the `extraEnv` entirely. Outcome: `module.application` has **no** `values` argument.
  - [x] No real consumer found → took the removal path (not the single-level fallback).
- [x] **Task 4 — Add secret-before-sync ordering (AC: 4)**
  - [x] On `module.application` (airflow), add `depends_on = [kubernetes_secret.airflow_config_credentials, kubernetes_secret.airflow_metadata, kubernetes_secret.airflow_result_backend]`.
  - [x] Did **not** add `depends_on` to `module.application_db` (postgres) — it doesn't consume these secrets.
- [x] **Task 5 — Confirm official-chart application wiring (AC: 5)**
  - [x] Verified `module.application` source/repo_url/path/target_revision/value_files match D6 (wrapper chart at `helms/airflow`, `HEAD`, default `values.yaml`). No change beyond values/depends_on — confirmed, no churn.
- [x] **Task 6 — Validate & commit (AC: 6)**
  - [x] `cd terraform/main && terraform fmt && terraform validate` → Success (no fmt diff). Diff scoped to `12-airflow.tf` (+ legit terraform-docs regen of the `main` resources table).
  - [x] Ran `pre-commit`; reverted the unrelated argocd `<br>`→`<br/>` doc churn (kept the legit `airflow_result_backend` row in `main.md`/`main/readme.md`). Pre-existing helms `detect-secrets` noise on untouched `values.yaml:16/19/24` (`*SecretName` keyword false-positives) is out of scope and does not block (git pre-commit hook not installed).
  - [x] Committed on `feat/airflow-3-k8s-133-upgrade`.

## Dev Notes

### Critical guardrails

- **Reuse the generic module — do NOT create a new one (D6).** data-platform's dedicated airflow TF module exists only for AWS wiring (RDS/IRSA/SecretsManager). Here, everything goes through the existing `modules/k8s/argocd/application`. The module already supports `values` (yamlencode'd), `parameters` (dynamic helm params), `path`, `value_files`, `target_revision`. `depends_on` is the standard Terraform module meta-argument.
- **One password source (NFR3).** `random_password.postgres.result` must feed **all three** places: the Postgres DB (`application_db.auth.password`), the metadata connection, and the result-backend connection. A mismatch = metadata/Celery auth failure at runtime (2.7). This is the *whole point* of the reconcile — Story 2.1 created the random password but left the DB on plaintext `"data"`, so they currently disagree.
- **`db+` prefix is load-bearing.** Airflow's Celery result backend URL uses the `db+` SQLAlchemy-style prefix (`db+postgresql://...`); the metadata secret uses bare `postgresql://...`. Do not unify them — they are different config surfaces. The chart does NOT derive the result backend from `metadataSecretName`.
- **extraEnv was community-chart vestigial.** The old community `airflow-helm` chart used a different value path (hence the `airflow.airflow.*` double-nest). The official chart's wrapper aliases everything under `airflow:` once. Since nothing reads `DATA_*`, removing the block is both the nesting fix and a plaintext-removal win. Don't "fix" it by keeping dead env.
- **No live apply.** The docker driver can't route `argocd.data:443` from the host without `minikube tunnel`; ArgoCD sync + app health is explicitly Story 2.7. The gate here is `terraform validate`.

### Current state (file being modified — UPDATE)

`terraform/main/12-airflow.tf` (read in full this session). Relevant existing pieces to **preserve**:

- `random_password.postgres` (length 24, `special = false`) — already defined; reuse `.result`. Same for `random_bytes.fernet_key`, `random_password.{api_secret_key,jwt_secret,admin}`.
- `kubernetes_secret.airflow_config_credentials` (keys: `fernet-key`, `api-secret-key`, `jwt-secret`, `admin-password`) — unchanged; referenced by `depends_on`.
- `kubernetes_secret.airflow_metadata` (key `connection` = `postgresql://mini:${random_password.postgres.result}@postgres-postgresql.data.svc...`) — **already** uses the random password; unchanged. The new result-backend secret mirrors this with the `db+` prefix.
- `module.project` (argocd project `mini-data-platform`), `module.application_db` (postgres, chart `postgresql` 14.2.4, bitnamilegacy image params from Story 2.5) — preserve all except `auth.password`.
- `module.application` (airflow, `path = "helms/airflow"`, `target_revision = "HEAD"`) — fix `values`, add `depends_on`.

Changes this story (UPDATE, scoped to one file):
1. **NEW** `kubernetes_secret.airflow_result_backend`.
2. `module.application_db.parameters["auth.password"]` → `random_password.postgres.result`.
3. `module.application` — remove double-nested `extraEnv` `values` block; add `depends_on` on the 3 secrets.

### Generic application module interface (reference)

`modules/k8s/argocd/application/01-application.tf` renders `argocd_application` with `helm { value_files, values = yamlencode(var.values), dynamic parameter {...} }`. Inputs (`00-variables.tf`): `name, project_name, repo_url, cluster_name, argocd_namespace, namespace, path, chart, target_revision, value_files=["values.yaml"], history_limit, parameters={}, values=null`. So `values` is an optional map; passing `null`/omitting it renders no inline values (the chart still reads `values.yaml` via `value_files`). [Source: terraform/modules/k8s/argocd/application/01-application.tf, 00-variables.tf]

### values.yaml contract (already in place from 2.3 — do NOT edit values.yaml here)

`helms/airflow/values.yaml` already sets `airflow.data.resultBackendSecretName: airflow-result-backend`, `airflow.data.metadataSecretName: airflow-metadata`, `airflow.fernetKeySecretName`/`apiSecretKeySecretName: airflow-config-credentials`. This story only creates the missing TF secret + wiring; the chart side is done. [Source: helms/airflow/values.yaml:13-24]

### Testing standards

- Gate: `terraform fmt` (no diff) + `terraform validate` (Success) from `terraform/main`.
- Sanity: `grep '"data"' terraform/main/12-airflow.tf` should return **no** password-literal hit after Task 2 (the only acceptable `data`-ish strings are the namespace `"data"` local and `mini_data_platform`).
- Sanity: confirm exactly one new `kubernetes_secret` resource and that `depends_on` lists all three secrets.
- No unit-test framework for TF here; review + validate is the bar (consistent with Stories 2.1–2.5).

### Project Structure Notes

- File numbering preserved — all D4 secret/random + airflow/postgres apps live in `terraform/main/12-airflow.tf` (architecture F7 mandates this single file, not a new module). [Source: architecture.md#D6, #F7]
- Modular structure intact — reusing `modules/k8s/argocd/application`; composing in `12-airflow.tf`. No inline resources beyond the secrets the architecture explicitly places here.

### Previous Story Intelligence

- Branch `feat/airflow-3-k8s-133-upgrade`; latest commit `3373dde` (Story 2.4 py312 pre-commit fixes). Stories 2.1–2.5 done. Continue here.
- **2.1 learnings:** the random_password/random_bytes resources and the two secrets already exist; 2.1 deliberately deferred the password reconcile + result-backend secret + depends_on to this story. Don't recreate the randoms.
- **2.5 learnings:** `module.application_db.parameters` already holds the bitnamilegacy image overrides next to `auth.*`; only `auth.password` changes. Diff stayed tightly scoped; review was clean. Same discipline expected here.
- **Gotcha (confirmed):** pre-commit terraform-docs emits `<br/>` where committed argocd READMEs have `<br>` → `git checkout --` the unrelated doc churn after pre-commit to keep commits scoped.
- **Gotcha:** `random_*` have no `keepers` — acceptable for this disposable local DB (per 2.1 deferral notes); not in scope to add.

### References

- [Source: docs/planning-artifacts/epics.md#Story 2.6] — ACs, reuse-module, depends_on, no-drift.
- [Source: docs/planning-artifacts/architecture.md#D6 — Terraform Shape] — reuse generic module, secrets + randoms in `12-airflow.tf`, no new module.
- [Source: docs/planning-artifacts/architecture.md#D4, #D7, lines 136/141/150/241] — D4 secrets must exist before sync (depends_on ordering); single-file numbering.
- [Source: docs/implementation-artifacts/deferred-work.md] — folds in: 2.1 "wire postgres password + remove plaintext" (High), 2.1 "depends_on on secrets" (Med), 2.3 "create airflow-result-backend Secret" (High), 2.3 "fix extraEnv nesting + remove DATA_* plaintext" (Med).
- [Source: terraform/main/12-airflow.tf] — current secrets + both apps (read in full this session).
- [Source: terraform/modules/k8s/argocd/application/{00-variables,01-application}.tf] — module interface.
- [Source: helms/airflow/values.yaml:13-24] — secret-name references already in place.
- [Source: docs/project-context.md] — TF conventions, file numbering, auto-doc gotcha, commit style.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (1M context)

### Debug Log References

- `terraform fmt` → no diff; `terraform validate` → **Success! The configuration is valid.**
- Plaintext check: `grep '"data"' terraform/main/12-airflow.tf` → only the namespace local (`namespace = "data"`) + one comment; **no password literal remains**.
- Consumer check: `grep -rn 'DATA_DB|DATA_USER|DATA_PASSWORD|extraEnv'` across `airflow/ helms/ terraform/` → only the `12-airflow.tf` definition site (no consumer) → confirmed safe to delete the `extraEnv` block.
- Doc churn: terraform-docs regenerated 6 files; kept the 2 legit `main` files (new `airflow_result_backend` resource row), reverted 4 unrelated argocd-module `<br>`→`<br/>` files (known gotcha).
- Pre-existing (out of scope): helms `detect-secrets` flags `values.yaml:16/19/24` (`*SecretName` keyword false-positives, unchanged vs HEAD); `.git/hooks/pre-commit` not installed so it does not block commits.

### Completion Notes List

- ✅ AC1: Added `kubernetes_secret.airflow_result_backend` (key `connection`, `db+postgresql://` prefix) next to `airflow_metadata`.
- ✅ AC2 (NFR3 complete): `module.application_db.auth.password` → `random_password.postgres.result`; removed all plaintext `"data"` password literals. DB + metadata + result-backend now derive from one password source.
- ✅ AC3: Removed the community-vestigial double-nested `values.airflow.airflow.extraEnv` block entirely (no repo consumer for `DATA_*`); `module.application` now has no inline `values`.
- ✅ AC4: `module.application` `depends_on` all three secrets (config-credentials, metadata, result-backend) — secrets exist before ArgoCD sync.
- ✅ AC5: Confirmed reuse of generic `modules/k8s/argocd/application` (not replaced); `path=helms/airflow`, `target_revision=HEAD`, default `value_files` unchanged.
- ✅ AC6: `fmt`/`validate` pass; commit scoped to `12-airflow.tf` + legit doc regen. Committed `73cba7a`.
- Runtime verification (apps Synced/Healthy, broker, login, base_url/TLS) is deferred to Story 2.7 per scope boundary.

### Review Findings

_Pending code review._

### File List

- `terraform/main/12-airflow.tf` (modified) — new `kubernetes_secret.airflow_result_backend`; `application_db.auth.password` → random password; removed vestigial `extraEnv` values block; added `depends_on` on 3 secrets.
- `docs/terraform/main.md` (modified) — terraform-docs regen: new `airflow_result_backend` resource row.
- `terraform/main/readme.md` (modified) — terraform-docs regen: new `airflow_result_backend` resource row.
- `docs/implementation-artifacts/deferred-work.md` (modified) — marked the 4 folded-in items RESOLVED; recorded the declined low-priority derive-from-params item.

## Change Log

| Date | Change |
|------|--------|
| 2026-06-20 | Story 2.6 created (ready-for-dev). Folds in deferred items: result-backend secret (2.3), postgres-password reconcile + plaintext removal / NFR3 (2.1), extraEnv nesting fix + DATA_* removal (2.3), secret-before-sync depends_on (2.1). Code-only; validate is the gate (live apply = 2.7). |
| 2026-06-20 | Implemented all 6 ACs in `12-airflow.tf`; `terraform validate` Success; no plaintext password remains (NFR3). Reverted unrelated argocd doc churn. Status → review. |
