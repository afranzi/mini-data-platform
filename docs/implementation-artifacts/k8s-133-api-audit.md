# Kubernetes 1.29 → 1.33 API & Provider Audit

**Story:** 1.2 · **Date:** 2026-06-19 · **Target:** Kubernetes `v1.33.x` · **Branch:** `feat/airflow-3-k8s-133-upgrade`

> **Correction (2026-06-20):** the target patch was originally written as `v1.33.10`, but minikube has no such version — its latest 1.33 patch is **`v1.33.4`** (corrected in `01-cluster.tf` during Story 1.3). The API-audit conclusions below are **patch-independent** (API removals are per-*minor*, 1.29→1.33), so they hold unchanged for `v1.33.4`. The minikube **driver** was also switched `qemu2`→`docker` (IT firewall blocks VM-driver SSH) — see `sprint-change-proposal-2026-06-20`.

Audit produced for FR2 / AR13 / AR14 to inform the Airflow 3 cutover (Epic 2) and the cluster recreate (Story 1.3).

## Tooling
- `pluto` 5.24.0 (`pluto detect-files --target-versions k8s=v1.33.10`)
- `kubent` 0.7.3 (file mode, `-t 1.33.10`, cluster/helm collectors disabled)
- Manual `grep` for known removed beta API groups
- `helm` CLI v4.0.4 used to render charts; `minikube` CLI v1.37.0 present

## Manifests audited (rendered, not live)
| Surface | How rendered | Result |
|---------|--------------|--------|
| Airflow community chart 8.8.0 (`helms/airflow` wrapper) | `helm dependency update` + `helm template` (3,277 lines) | ✅ clean |
| Bitnami PostgreSQL 14.2.4 (`module.application_db`) | `helm template bitnami/postgresql --version 14.2.4` (308 lines) | ✅ clean |
| minikube addons (ingress-nginx, ingress-dns, metrics-server, storage) | upstream, minikube-managed | informational (see below) |
| ArgoCD install (`modules/k8s/argocd/server`) | upstream `argo-cd` chart `6.4.0`, app `v2.10.1` | see finding A-2 |

## API audit result: ✅ CLEAN

- **pluto:** "There were no resources found with known deprecated apiVersions."
- **kubent:** no findings in file mode.
- **apiVersions actually in use** across rendered manifests — all stable on 1.33:
  `v1` (core), `apps/v1`, `networking.k8s.io/v1` (Ingress), `rbac.authorization.k8s.io/v1`.
- **No** occurrences of removed/deprecated groups: `flowcontrol.apiserver.k8s.io/v1beta2` (removed 1.29) or `v1beta3` (removed 1.32), `policy/v1beta1`/`PodSecurityPolicy`, `autoscaling/v2beta*`, `batch/v1beta1`.
- **Informational deprecations (still served in 1.33, no action now):** core `v1 Endpoints` → prefer `discovery.k8s.io/v1 EndpointSlice`; pod `status.resize`. Neither blocks the upgrade.

> The community Airflow chart is replaced wholesale by the official Apache chart in Epic 2, so any in-chart specifics are mooted by the cutover — the durable value here is that **Postgres, ingress, and the workload API surface are clean on 1.33**.

## Provider compatibility (AR13 / AR14)

| Provider | Before | After | Verdict |
|----------|--------|-------|---------|
| `scott-the-programmer/minikube` | `~> 0.3.10` (0.3.10) | **`~> 0.6.0` (0.6.0)** | **BUMPED.** Provider *embeds* `k8s.io/minikube` (v1.38.1 in 0.6.0); 0.3.10's embedded minikube predates 1.33 and could not provision `v1.33.10`. Resolves Story 1.1 review finding #1. |
| `hashicorp/kubernetes` | `~> 2.26.0` | unchanged | OK. Client-API provider; only manages `namespace`/`secret` (core/v1, stable). Backward-compatible with 1.33. No bump needed. |
| `hashicorp/helm` | `~> 2.12.1` | unchanged | OK. Wraps Helm 3 SDK; chart delivery is k8s-version tolerant for the resources used. No bump needed. |
| `oboukili/argocd` | `6.0.3` | unchanged | OK functionally, **but see finding A-1**. |

`terraform init -upgrade` resolved minikube → 0.6.0; others held. `terraform fmt`/`validate` pass.

## Findings to carry into later stories

- **A-1 [Low → follow-up] `oboukili/argocd` provider is relocated.** `terraform init` emitted: provider moved to `registry.terraform.io/argoproj-labs/argocd`. `oboukili/argocd 6.0.3` still works, but it's effectively the legacy address. Recommend migrating to `argoproj-labs/argocd` in a future housekeeping change (not required for 1.33). Owner: housekeeping / Epic 3.
- **A-2 [Med → Story 1.3] ArgoCD app version is old for 1.33.** ArgoCD installs via chart `6.4.0` / image `v2.10.1` (early 2024), which predates official k8s 1.33 support. It will likely run, but **Story 1.3 must confirm ArgoCD comes up Synced/Healthy on 1.33**; if it misbehaves, bump `argocd_helm_chart_version`/`argocd_version` (defaults in `modules/k8s/argocd/server/00-variables.tf`). Covers G3.
- **A-3 [Med → Story 1.3] minikube addon compatibility is runtime-verified.** ingress-nginx + metrics-server addons are minikube-managed; minikube v1.37 ships 1.33-compatible addons, but confirm no addon pod CrashLoops after the recreate (FR3).
- **A-4 [informational] EndpointSlice / pod resize deprecations** — track for future (1.34+), no action for this upgrade.

## Conclusion
No repo-owned manifest required an API change for k8s 1.33. The single required change was the **minikube provider bump** (done). ArgoCD-app and addon health are runtime checks owned by Story 1.3.
