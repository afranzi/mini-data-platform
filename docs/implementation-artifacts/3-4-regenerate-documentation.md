---
baseline_commit: 87c5d70297b145fc3d1489e28a8cba864b4a89f8
---

# Story 3.4: Regenerate Documentation

Status: done

## Story

As a maintainer,
I want all generated and authored docs refreshed to reflect the upgraded platform,
so that the docs match Airflow 3.0 / k8s 1.33 and pre-commit passes across all areas (FR22, NFR4).

## Acceptance Criteria

1. **Auto-generated blocks regenerated, not hand-edited (FR22).** Running `scripts/helm_docs.sh` and `scripts/terraform_docs.sh` (and the helm-docs/terraform-docs pre-commit hooks) leaves the `<!-- BEGIN_TF_DOCS -->`/helm-docs blocks consistent with the current `.tf` variable descriptions and `values.yaml`. No manual edits inside generated regions.
2. **mkdocs / authored pages reflect the upgrade.** Pages that describe versions reflect **Airflow 3.2.2 / k8s 1.33.4**: `docs/helms/airflow.md` (generated) + the authored `docs/project-context.md` (currently says Kubernetes `v1.29.2`, Airflow `^2.8.0`, target `1.18.0`/`3.0.2`) updated to the landed state.
3. **Stale operational docs corrected (deferred from 1.3 review).** `terraform/main/readme.md` quickstart no longer instructs `brew install socket_vmnet` / `sudo brew services start socket_vmnet` (qemu era) — it documents the **docker driver** + `minikube tunnel` (+ `/etc/hosts` → **`127.0.0.1`** argocd.data/airflow.data). The `terraform/modules/k8s/minicluster/main.tf` doc comment that says "the docker driver does not support the ingress add-on so we advise to use the qemu driver" is corrected (we run docker with ingress-nginx; host access via tunnel).
4. **pre-commit passes across all areas (NFR4).** `pre-commit run --all-files` (terraform, python, helms, docs) passes; only intended doc regenerations are committed; the known argocd `<br>`→`<br/>` churn on **unrelated** module docs is reverted to keep the commit scoped.

> ⚠️ **Scope boundary:** documentation only — refresh generated blocks + correct stale authored docs to match the landed platform. No `.tf`/chart/DAG behavior changes. Don't hand-edit generated regions (edit the `.tf` descriptions / `README.md.gotmpl` source instead).

## Tasks / Subtasks

- [x] **Task 1 — Regenerate auto-docs (AC: 1, 4)** — ran the terraform-docs + helm-docs pre-commit hooks + the `scripts/*_docs.sh` copies. minicluster readme regenerated from the corrected header comment; `docs/terraform/main.md` re-copied from the readme prose. Reverted the unrelated argocd `project` module `<br>`→`<br/>` churn (local-tool version drift).
- [x] **Task 2 — Refresh `docs/project-context.md` versions (AC: 2)** — k8s `v1.29.2`→`v1.33.4`; Airflow `^2.8.0` custom chart → `3.2.2` official chart `1.22.0`; minikube provider `0.3.10`→`0.6.0`; Python `3.10`→`3.12`; dropped "UPGRADE TARGET" framing; rewrote DAG-authoring (`airflow.sdk` / `ScheduleArg`) + "Upgrade Gotchas"→"Platform Operational Gotchas" (landed); host-access note → `127.0.0.1`; dates → 2026-06-21.
- [x] **Task 3 — Correct stale operational docs (AC: 3)** — `terraform/main/readme.md`: replaced the qemu/socket_vmnet quickstart with the docker-driver + `sudo minikube tunnel` + `/etc/hosts → 127.0.0.1` flow, cross-linked the 3.1 runbook (authored prose only; TF_DOCS block untouched). `minicluster/main.tf` header comment: fixed the "docker driver does not support ingress" claim → docker + ingress-nginx + tunnel.
- [x] **Task 4 — Verify + finalize (AC: 2, 4)** — terraform `fmt`/`validate`/trivy/tflint, python, helm-docs hooks **pass**; generated markers intact, version refs correct. The terraform-docs hook still rewrites the `project` module doc with `<br/>` (known local-tool-vs-CI version drift, not from this story) — reverted to keep scope; it does not block commits (git pre-commit hook not installed). Tracked as housekeeping in deferred-work.

## Dev Notes

### Critical guardrails

- **Never hand-edit generated regions.** Terraform `readme.md` and Helm `README.md` content between `<!-- BEGIN_TF_DOCS -->`/`<!-- END_TF_DOCS -->` (and the helm-docs markers) is generated. Edit the `.tf` variable `description`s or `README.md.gotmpl` and **regenerate** — do not type inside the markers (project-context rule). Authored prose OUTSIDE the markers (quickstart, comments) is fair game.
- **`scripts/*_docs.sh` only COPY** the per-module `readme.md` into `docs/<path>.md` — the actual terraform-docs/helm-docs **injection** happens via the pre-commit hooks (`cd terraform && pre-commit run` / `cd helms && pre-commit run`). So to regenerate: run the pre-commit hooks (which rewrite the `readme.md`/`README.md`), THEN `scripts/terraform_docs.sh`/`scripts/helm_docs.sh` to copy into `docs/`. (Learned in Story 3.1.)
- **`<br>`→`<br/>` drift gotcha:** the local terraform-docs emits `<br/>` where committed module READMEs have `<br>`. After regen, `git checkout --` the churn on modules this story didn't substantively change, to keep the commit scoped. (A proper fix — aligning local tool versions with CI — is a separate housekeeping item.)
- **detect-secrets noise:** the helms hook flags `values.yaml` `*SecretName:` lines (names, not values) — expected false positives, not blockers (git pre-commit hook isn't installed; Story 3.2 confirmed NFR3 holds).
- **Docs must match the LANDED state**, not the in-flight target framing. The upgrade is complete on `main`: k8s `v1.33.4`, Airflow `3.2.2` (official chart `1.22.0`), CeleryExecutor + standalone dag-processor, SimpleAuth, gitSync, automated ArgoCD syncPolicy.

### Current state (files to touch — all docs/prose, no behavior)

- `docs/project-context.md` (UPDATE authored) — stale: `v1.29.2`, Airflow `^2.8.0`, target `1.18.0`/`3.0.2` (lines ~28/33-34). Refresh to landed versions; flip "UPGRADE TARGET" → done. Fix host-access note to `127.0.0.1`.
- `terraform/main/readme.md` (UPDATE authored quickstart only) — stale socket_vmnet/qemu setup. Replace with docker + tunnel + `/etc/hosts 127.0.0.1`; link the runbook. Leave the TF_DOCS block to regeneration.
- `terraform/modules/k8s/minicluster/main.tf` (UPDATE comment) — misleading "docker driver does not support ingress" comment.
- Generated/derived (regenerate, don't hand-edit): `helms/airflow/README.md` + `docs/helms/airflow.md`; `terraform/**/readme.md` + `docs/terraform/**.md`.

### Testing standards

- Docs story: "tests" = `pre-commit run --all-files` green + a visual/diff review that generated blocks match source and version refs are correct. Capture the pre-commit result. No unit tests.

### Previous Story Intelligence

- On `main`; HEAD `87c5d70`. Epic 3: 3.1 done, 3.2 done, **3.3 descoped**. 3.4 is the **last story** → Epic 3 + the whole upgrade can close after this.
- **Landed versions to write:** k8s `v1.33.4` (minikube docker driver); Airflow `3.2.2` via official Apache chart `1.22.0`; Python `3.12`; CeleryExecutor/Redis; SimpleAuth; gitSync (`main`, `airflow` subPath); automated ArgoCD syncPolicy (3.1).
- **Doc-tooling mechanics (from 3.1):** `scripts/*_docs.sh` only copy; the pre-commit hooks do the injection. Run hooks first, then the copy scripts. Revert the `<br>` churn after.
- **Several 3.4 items were pre-collected** in `deferred-work.md` (1.3-review docs section): socket_vmnet readme staleness, minicluster comment, project-context version refresh — all folded into Tasks 2/3 here.

### References

- [Source: docs/planning-artifacts/epics.md#Story 3.4] — regenerate helm/terraform docs; mkdocs reflect 3.0/1.33; pre-commit passes.
- [Source: docs/implementation-artifacts/deferred-work.md] — 1.3-review docs items (socket_vmnet readme, minicluster comment, project-context version) + the doc-tooling `<br>` drift note.
- [Source: docs/project-context.md] — the stale authored doc to refresh.
- [Source: docs/runbooks/clean-state-bring-up.md] — runbook to cross-link from the readme.
- [Source: scripts/helm_docs.sh, scripts/terraform_docs.sh] — copy-only scripts; injection is via pre-commit.
- [Source: docs/project-context.md#Auto-Generated Docs] — do-not-hand-edit rule.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

- ✅ **AC1** — auto-doc blocks regenerated via the terraform-docs/helm-docs hooks (minicluster readme from the corrected header comment); no hand-edits inside generated markers.
- ✅ **AC2** — `docs/project-context.md` refreshed to the landed state (k8s v1.33.4, Airflow 3.2.2 / official chart 1.22.0, Python 3.12, provider 0.6.0, airflow.sdk DAG authoring, 127.0.0.1 host access); `docs/terraform/main.md` + `docs/terraform/modules/k8s/minicluster.md` re-synced.
- ✅ **AC3** — `terraform/main/readme.md` quickstart rewritten (docker driver + tunnel + /etc/hosts→127.0.0.1, runbook link); `minicluster/main.tf` misleading ingress comment fixed.
- ⚠️ **AC4** — functional hooks (terraform fmt/validate/trivy/tflint, python, helm-docs) **pass**; the terraform-docs hook keeps rewriting the **project** module doc with `<br/>` (local terraform-docs vs committed `<br>` — pre-existing version drift, NOT from this story). Reverted to keep the commit scoped; doesn't block (git hook not installed). Housekeeping fix (align tool versions) remains in deferred-work.
- Folded in the three 1.3-review doc items (socket_vmnet readme, minicluster comment, project-context versions).

### Review Findings

_Code review 2026-06-21 — **clean**. Docs-only story; the review adversarially scanned authored docs for surviving stale refs (`v1.29`, `2.8.0`, `0.3.10`, `1.18.0/3.0.2`, `192.168.105`, `schedule_interval`) → none remain (the qemu2/socket_vmnet/192.168.49.2 mentions that do appear are intentional context explaining the docker-driver/tunnel choice). AC1/2/3 PASS; AC4 PASS-with-caveat (terraform-docs `<br>` version drift on the project module is pre-existing tooling drift, reverted + tracked, doesn't block). No findings._

### File List

- `docs/project-context.md` (modified) — versions/DAG/gotchas refreshed to landed state.
- `terraform/main/readme.md` (modified) — docker-driver + tunnel + 127.0.0.1 quickstart (authored prose; TF_DOCS block untouched).
- `docs/terraform/main.md` (modified) — re-copied from readme.md.
- `terraform/modules/k8s/minicluster/main.tf` (modified) — corrected ingress/driver header comment.
- `terraform/modules/k8s/minicluster/readme.md` + `docs/terraform/modules/k8s/minicluster.md` (modified) — regenerated from the comment.
- `docs/implementation-artifacts/deferred-work.md` (modified) — incidental trailing-whitespace trim by pre-commit.

## Change Log

| Date | Change |
|------|--------|
| 2026-06-21 | Story 3.4 created (ready-for-dev). Docs-only: regenerate helm/terraform-docs blocks; refresh `project-context.md` + `terraform/main/readme.md` + minicluster comment to the landed Airflow 3.2.2 / k8s 1.33.4 state (folds in 1.3-review doc items); pre-commit green. Last Epic 3 story. |
| 2026-06-21 | Refreshed all authored/generated docs to the landed state; functional pre-commit hooks pass (terraform-docs project `<br>` drift reverted as known housekeeping). Status → review. |
