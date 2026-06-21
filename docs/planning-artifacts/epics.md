---
stepsCompleted: [1, 2, 3, 4]
status: complete
completedAt: 2026-06-19
inputDocuments:
  - docs/planning-artifacts/prds/prd-mini-data-platform-2026-06-19/prd.md
  - docs/planning-artifacts/prds/prd-mini-data-platform-2026-06-19/addendum.md
  - docs/planning-artifacts/architecture.md
  - docs/project-context.md
---

# mini-data-platform - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for the **Airflow 3.0 & Kubernetes 1.33 upgrade** of mini-data-platform, decomposing the requirements from the PRD and Architecture into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: minikube `kubernetes_version` is set to a pinned `v1.33.x` and the cluster comes up on that version.
FR2: The cluster is audited for deprecated/removed APIs (pluto/kubent); manifests using removed API groups are updated.
FR3: All existing platform workloads (ArgoCD, ingress-nginx, PostgreSQL, Airflow) are running and Healthy on 1.33.
FR4: The `helms/airflow` chart dependency is switched from community `airflow-helm/charts` to the official Apache chart (latest stable), preserving the wrapper-chart pattern.
FR5: `Chart.yaml` `appVersion` tracks the deployed Airflow 3.x image; the dependency version is pinned.
FR6: `values.yaml` is ported from the community-chart schema to the official-chart schema.
FR7: CeleryExecutor is retained, with Redis broker and Celery workers enabled.
FR8: The Airflow 3 component set is deployed and Healthy: api-server, scheduler, standalone dag-processor, triggerer, workers.
FR9: The web UI uses SimpleAuthManager with a configured admin user; credentials supplied via secret, not committed plaintext.
FR10: DAGs load via gitSync from the public repo `airflow` subpath.
FR11: nginx ingress at host `airflow.data` points at the api-server service, with health check on the v2 API path.
FR12: DB schema migration runs via `airflow db migrate`, wired as an ArgoCD sync-hook job.
FR13: Airflow 3 secret handling configured: `[api] secret_key` and JWT secret set so the Task Execution API works.
FR14a: ChesterDag base import migrated to `airflow.sdk.DAG` and SDK types (e.g. ScheduleArg).
FR14b: DAG scheduling uses the standardized `schedule` argument (no `schedule_interval`/`timetable`).
FR14c: Any `airflow.configuration.conf` usage validated as parse-time-safe (no task-time metadata-DB access).
FR15: The example DAG and any other DAGs parse cleanly and run successfully on Airflow 3.
FR16: Airflow-3 migration linting added to pre-commit/CI: Ruff AIR301/AIR302 and `airflow config lint` pass.
FR17a: `pyproject.toml` `apache-airflow` bumped to 3.x, with required providers added (FAB not needed for SimpleAuth).
FR17b: Python toolchain aligned on 3.12 (pyproject constraint, runtime image tag, black/flake8/mypy/pytest configs).
FR18: Embedded Bitnami PostgreSQL held at 14.2.4 but image sources overridden to `bitnamilegacy/*`.
FR19: ArgoCD `airflow` project & application updated for the new chart/path and remain Synced/Healthy; Postgres app updated for FR18.
FR20: `terraform/main/12-airflow.tf` Helm values/parameters updated to the new schema; `terraform apply` completes cleanly with no drift.
FR21: Create-user and DB-migrate jobs keep `useHelmHooks: false` with ArgoCD sync-hook annotations.
FR22: helm-docs and terraform-docs regenerated for the changed chart/modules; affected mkdocs pages updated.

### NonFunctional Requirements

NFR1: Reproducibility — clean `terraform apply` brings up the whole platform with no manual steps.
NFR2: Resource footprint — Airflow 3 component set fits the minikube allocation (gate: no Pending/OOMKilled); minikube `--cpus`/`--memory` is the lever.
NFR3: Secret hygiene — no secrets (admin password, fernet, api/JWT keys) committed in plaintext.
NFR4: Convention adherence — TF file-numbering, auto-gen docs untouched, pre-commit per-area hooks, gitmoji commits.
NFR5: Rollback — documented revert path for the combined change.

### Additional Requirements

(From Architecture decisions D1–D10 and validation.)
- AR1 (D1): Combined upgrade delivered as two separable commits — k8s 1.33 first (existing stack stays Healthy), then Airflow 3 cutover.
- AR2 (D2): Wrapper chart depends on official Apache chart 1.22.0 (Airflow 3.2.2); values.yaml is a full schema rewrite (highest-risk artifact).
- AR3 (D3): Component topology — scheduler, api-server, standalone dag-processor, triggerer, Celery workers (1 replica, no persistence), Redis (no persistence).
- AR4 (D4): All secrets are Terraform-managed k8s Secrets (`airflow-metadata`, `airflow-config-credentials`) via `random_password`, referenced by chart `*SecretName` values.
- AR5 (D5): `migrateDatabaseJob` runs `airflow db migrate` as an ArgoCD sync-hook (`useHelmHooks: false`).
- AR6 (D6): Reuse generic `modules/k8s/argocd/application`; add secret + random_password resources in `12-airflow.tf`. No new module.
- AR7 (D7): nginx ingress → api-server svc; probes on `/api/v2/monitor/health`.
- AR8 (D8): bitnamilegacy image overrides set in one place (Postgres app parameters in `12-airflow.tf`).
- AR9 (D9): DAG code + Python 3.12 + chart cutover land atomically (gitSync self-reference).
- AR10 (D10): Conservative per-component resource requests/limits; raise minikube allocation rather than drop components.
- AR11: First implementation priority — k8s 1.33 bump + deprecated-API audit before chart cutover.
- AR12 (G1): Verify SimpleAuthManager admin config path vs the chart's create-user job (may need disabling).
- AR13 (G2): Verify TF provider versions (`helm ~>2.12`, `kubernetes ~>2.26`) for k8s 1.33 + official-chart rendering.
- AR14 (G3): Verify ArgoCD install + `oboukili/argocd 6.0.3` provider healthy on 1.33.

### UX Design Requirements

N/A — infrastructure upgrade, no UI work.

### FR Coverage Map

FR1–3   → Epic 1 (k8s 1.33 bump, API audit, workloads healthy)
FR4–6   → Epic 2 (official chart adoption + values port)
FR7–13  → Epic 2 (Airflow 3 runtime: executor, components, auth, ingress, migrate, secrets)
FR14a–17b → Epic 2 (DAG/ChesterDag + Python 3.12 + lint — co-deployed with the chart)
FR18    → Epic 2 (bitnamilegacy Postgres images)
FR19–21 → Epic 2 (ArgoCD app/project, terraform apply, hooks)
FR22    → Epic 3 (docs regeneration)
NFR1,2,3,5 → Epic 3 (verification gates); NFR4 enforced across all epics (conventions)

## Epic List

### Epic 1: Kubernetes 1.33 Cluster Upgrade
Bring the local cluster onto Kubernetes 1.33 with the existing Airflow 2.8.2 stack still Healthy — isolating and de-risking the cluster variable before any Airflow change.
**FRs covered:** FR1, FR2, FR3
**Refs:** AR1, AR11, AR13, AR14

### Epic 2: Airflow 3.0 Cutover (Official Chart + Runtime + DAG Migration)
Replace the community chart with the official Apache Airflow chart and stand up Airflow 3.0 end-to-end: component topology, Terraform-managed secrets, ingress, DB migrate, Postgres image sourcing, and the DAG/tooling compatibility changes — all delivered atomically because gitSync pulls DAG code from this same repo.
**FRs covered:** FR4, FR5, FR6, FR7, FR8, FR9, FR10, FR11, FR12, FR13, FR14a, FR14b, FR14c, FR15, FR16, FR17a, FR17b, FR18, FR19, FR20, FR21
**Refs:** AR2–AR10, AR12

### Epic 3: Validation, Reproducibility & Documentation
Prove the upgrade holds end-to-end and lock it in: clean-state reproducibility, resource-footprint gate, secret-hygiene check, rollback rehearsal, and regenerated docs.
**FRs covered:** FR22
**Refs:** NFR1, NFR2, NFR3, NFR5

## Epic 1: Kubernetes 1.33 Cluster Upgrade

Bring the local minikube cluster onto Kubernetes 1.33 with the existing Airflow 2.8.2 stack still Healthy, isolating the cluster variable before any Airflow change (AR1, AR11).

### Story 1.1: Pin Kubernetes 1.33 in Terraform

As a platform operator,
I want the minikube cluster version pinned to a `v1.33.x` release in Terraform,
So that the cluster provisions on Kubernetes 1.33 reproducibly.

**Acceptance Criteria:**

**Given** `terraform/main/01-cluster.tf` currently sets `kubernetes_version = "v1.29.2"`
**When** I update it (and the `minicluster` module/provider plumbing) to a pinned `v1.33.x`
**Then** `terraform plan` shows the cluster version change and no unrelated drift
**And** the pinned version is an explicit patch (e.g. `v1.33.1`), not `stable`/`latest`
**And** the value flows through `modules/k8s/minicluster` without hardcoding elsewhere.

### Story 1.2: Audit Deprecated/Removed Kubernetes APIs

As a platform operator,
I want the cluster's manifests audited for APIs removed or deprecated between 1.29 and 1.33,
So that no workload breaks on the new cluster.

**Acceptance Criteria:**

**Given** the target is Kubernetes 1.33
**When** I run `pluto`/`kubent` against the rendered manifests (ArgoCD apps, ingress-nginx, postgres, Airflow)
**Then** any use of removed groups (e.g. `flowcontrol v1beta2/3`) is identified and updated to supported versions
**And** the TF providers (`helm ~>2.12`, `kubernetes ~>2.26`) and `oboukili/argocd 6.0.3` are verified compatible with 1.33, bumping versions if required (AR13, AR14)
**And** findings are noted so they inform the cutover.

### Story 1.3: Recreate Cluster and Verify Existing Stack Healthy

As a platform operator,
I want to apply the 1.33 cluster and confirm the current platform is fully Healthy,
So that I have a known-good baseline before the Airflow 3 cutover.

**Acceptance Criteria:**

**Given** Stories 1.1 and 1.2 are complete
**When** I recreate the cluster via `terraform apply` (minikube delete + recreate as needed)
**Then** the cluster reports server version 1.33.x
**And** ArgoCD, ingress-nginx, PostgreSQL, and the existing Airflow 2.8.2 application are all Synced/Healthy
**And** no pods are stuck `Pending` or `CrashLoopBackOff`.

## Epic 2: Airflow 3.0 Cutover (Official Chart + Runtime + DAG Migration)

Stand up Airflow 3.0 on the official Apache chart end-to-end. Stories are ordered so the chart, secrets, DAG code, and Terraform wiring are all in place before the single atomic ArgoCD sync (AR9). No story depends on a later one.

### Story 2.1: Provision Terraform-Managed Airflow Secrets

As a platform operator,
I want all Airflow secrets created as Terraform-managed Kubernetes Secrets,
So that no secret is committed in plaintext and the chart can reference them (NFR3, AR4).

**Acceptance Criteria:**

**Given** `terraform/main/12-airflow.tf`
**When** I add `random_password` resources and `kubernetes_secret` resources
**Then** secret `airflow-config-credentials` holds the fernet key, `[api] secret_key`, JWT secret, and the SimpleAuth admin password
**And** secret `airflow-metadata` holds the Postgres metadata connection
**And** no secret value appears in any committed file (`values.yaml`, `.tfvars`)
**And** the secret names match what the chart values will reference verbatim.

### Story 2.2: Switch Wrapper Chart to the Official Apache Chart

As a platform operator,
I want the `helms/airflow` wrapper to depend on the official Apache Airflow chart,
So that the platform runs the supported upstream chart (FR4, FR5, AR2).

**Acceptance Criteria:**

**Given** `helms/airflow/Chart.yaml` currently depends on `airflow-helm/charts` 8.8.0
**When** I change the dependency to the official chart (`airflow` from `https://airflow.apache.org`, pinned `1.22.0`) and set `appVersion` to the deployed Airflow image version (`3.2.2`)
**Then** `helm dependency update` resolves the official chart successfully
**And** the wrapper-chart pattern (all config under the `airflow:` alias) is preserved
**And** the pinned chart version is explicit (no floating range).

### Story 2.3: Port values.yaml to the Official-Chart Schema with Airflow 3 Topology

As a platform operator,
I want `values.yaml` rewritten to the official-chart schema with the Airflow 3 component set,
So that all components deploy correctly with local-appropriate config (FR6, FR7, FR8, FR9, FR10, FR11, FR12, FR13).

**Acceptance Criteria:**

**Given** the official chart dependency from Story 2.2 and the secrets from Story 2.1
**When** I rewrite `values.yaml` to the official schema
**Then** `executor: CeleryExecutor` with Redis enabled (no persistence) and 1 worker (AR3)
**And** the component set is configured: `apiServer`, `scheduler`, standalone `dagProcessor`, `triggerer`, `workers`
**And** `config.api`/fernet/JWT reference the `airflow-config-credentials` secret via `*SecretName` keys (FR13)
**And** auth uses SimpleAuthManager with the admin sourced from the secret (FR9)
**And** `dags.gitSync` points at the public repo `airflow` subpath, branch `main` (FR10)
**And** ingress is nginx at host `airflow.data` → api-server, health on `/api/v2/monitor/health` (FR11)
**And** `migrateDatabaseJob` runs `airflow db migrate` with `useHelmHooks: false` + `argocd.argoproj.io/hook: Sync` (FR12, FR21)
**And** the create-user job is reconciled with SimpleAuthManager (disabled or adjusted per AR12)
**And** conservative per-component requests/limits are set (AR10)
**And** `helm template` renders without schema errors.

### Story 2.4: Migrate DAG Code and Python Tooling to Airflow 3

As a DAG author,
I want `ChesterDag`, the example DAG, and the Python tooling migrated to Airflow 3 / Python 3.12,
So that DAGs parse and the toolchain enforces Airflow-3 compatibility (FR14a, FR14b, FR14c, FR16, FR17a, FR17b, AR9).

**Acceptance Criteria:**

**Given** the current DAG code uses `from airflow import DAG` / `airflow.models.dag`
**When** I migrate `ChesterDag` to subclass `airflow.sdk.DAG` with SDK `ScheduleArg`
**Then** DAGs use the `schedule=` argument (no `schedule_interval`/`timetable`) and the example DAG uses the SDK imports
**And** any `airflow.configuration.conf` usage is confirmed parse-time-safe (no task-time DB access)
**And** `pyproject.toml` sets `apache-airflow` to the target 3.x and the Python constraint to 3.12, with `poetry.lock` relocked
**And** black/flake8/mypy/pytest configs target Python 3.12
**And** Ruff `AIR301`/`AIR302` and `airflow config lint` run in pre-commit and report no incompatibilities.

### Story 2.5: Source Postgres Images from bitnamilegacy

As a platform operator,
I want the embedded Bitnami Postgres images sourced from the `bitnamilegacy` repos,
So that free image pulls keep working after the 2025 Bitnami catalog change (FR18, AR8).

**Acceptance Criteria:**

**Given** the Postgres ArgoCD application in `12-airflow.tf` (chart unchanged, PG 14.2.4)
**When** I set the image overrides in one place (the Postgres app `parameters`)
**Then** `image.repository=bitnamilegacy/postgresql`, `volumePermissions.image.repository=bitnamilegacy/os-shell`, and `metrics.image.repository=bitnamilegacy/postgres-exporter`
**And** the overrides are not split between values and parameters
**And** the Postgres pods pull successfully.

### Story 2.6: Update Terraform ArgoCD Application and Wiring

As a platform operator,
I want `12-airflow.tf` updated to deploy the new chart via the existing generic application module,
So that `terraform apply` provisions the cutover cleanly with no drift (FR19, FR20, FR21, AR6).

**Acceptance Criteria:**

**Given** the generic `modules/k8s/argocd/application` module (reused, not replaced)
**When** I update the `airflow` application's `path`/`values`/`parameters` for the official chart and add `depends_on` on the Story 2.1 secrets
**Then** `terraform plan`/`apply` completes cleanly with no unexpected drift
**And** the ArgoCD `airflow` project and application definitions are valid for the new chart/path
**And** secrets exist before the application syncs (ordering enforced).

### Story 2.7: Deploy and Verify Airflow 3.0 End-to-End

As a platform operator,
I want the cutover synced and verified end-to-end,
So that Airflow 3.0 is proven working before closing the epic (FR8, FR15; SM2, SM3, SM4).

**Acceptance Criteria:**

**Given** Stories 2.1–2.6 are complete on the feature branch
**When** ArgoCD syncs the airflow application
**Then** the `airflow` application is Synced/Healthy and all components (api-server, scheduler, dag-processor, triggerer, workers, Redis) are Healthy
**And** the UI is reachable at `https://airflow.data` and login works via the SimpleAuth admin
**And** the example `ChesterDag` DAG parses with no import/deprecation errors
**And** a manual run of the example DAG succeeds end-to-end.

## Epic 3: Validation, Reproducibility & Documentation

Prove the upgrade holds and lock it in: reproducibility, footprint/secret gates, rollback, and docs (NFR1, NFR2, NFR3, NFR5, FR22).

### Story 3.1: Clean-State Reproducibility Test

As a platform operator,
I want the whole platform to come up from a clean `terraform apply`,
So that the upgrade is reproducible with no manual steps (NFR1, SM1).

**Acceptance Criteria:**

**Given** a clean state (destroyed/fresh cluster)
**When** I run `terraform apply`
**Then** the full platform (k8s 1.33 + Airflow 3.0 + Postgres) stands up with zero manual post-steps
**And** ArgoCD reconciles all applications to Synced/Healthy automatically.

### Story 3.2: Resource-Footprint and Secret-Hygiene Verification

As a platform operator,
I want the footprint and secret hygiene verified,
So that the upgrade respects local limits and commits no secrets (NFR2, NFR3, CM1).

**Acceptance Criteria:**

**Given** the fully synced Airflow 3 stack
**When** I inspect pod scheduling and the repository
**Then** no pods are `Pending` (unschedulable) or `OOMKilled`; if needed, the minikube `--cpus`/`--memory` lever is documented as applied
**And** a scan of the repo confirms no fernet key, api/JWT secret, or admin password is committed in plaintext.

### Story 3.3: Rollback Rehearsal and Documentation — ❌ DESCOPED (2026-06-21)

> **Descoped by operator decision (2026-06-21):** old-version rollback (Airflow 2.8.2 / k8s v1.29.2) is not needed — the platform is local/disposable and Story 3.1 already proved a clean destroy + rebuild of the upgraded stack. NFR5 (revert path) is descoped accordingly. Original intent preserved below for history.

As a platform operator,
I want a verified rollback path documented,
So that I can revert the combined change safely (NFR5).

**Acceptance Criteria:**

**Given** the upgrade is on a feature branch
**When** I document and rehearse the rollback (revert branch + `terraform apply`, cluster recreate at the old version)
**Then** the platform returns to Airflow 2.8.2 / k8s v1.29.2 Healthy
**And** the rollback steps are recorded in the repo docs.

### Story 3.4: Regenerate Documentation

As a maintainer,
I want all generated and authored docs refreshed,
So that the docs reflect the upgraded platform (FR22, NFR4).

**Acceptance Criteria:**

**Given** the chart, Terraform, and DAG changes are complete
**When** I run `scripts/helm_docs.sh` and `scripts/terraform_docs.sh` and review mkdocs pages
**Then** the helm-docs and terraform-docs auto-generated blocks are regenerated (not hand-edited)
**And** affected mkdocs pages (`docs/helms/airflow.md`, terraform docs) reflect Airflow 3.0 / k8s 1.33
**And** pre-commit passes across all areas.
