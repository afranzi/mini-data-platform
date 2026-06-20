# Deferred Work

Tracks review findings that are real but not actionable in the story under review — assigned to a later story by the planned scope split. Pull these into the owning story when it is created/implemented.

## Deferred from: code review of 1-1-pin-kubernetes-1-33-in-terraform (2026-06-19)

- **[High] Provider may not serve k8s v1.33.10 → Story 1.2.** The minikube provider is locked at `~> 0.3.10` (`terraform/main/providers.tf`, `.terraform.lock.hcl`). Its bundled minikube may lack kubeadm/images for `v1.33.10`, so `terraform apply` could fail or **silently downgrade** to minikube's default version (FR1 unmet). Story 1.2 must verify provider/minikube support for 1.33.10 and bump `~> 0.3.10` + `terraform init -upgrade` if needed (AR13/G2).
- **[High] Deprecated/removed-API + addon audit → Story 1.2.** Audit manifests/addons (ingress, ingress-dns, metrics-server in `modules/k8s/minicluster/01-cluster.tf`; ArgoCD/oboukili provider; Postgres) for APIs removed/deprecated across 1.29→1.33 (e.g. `flowcontrol.apiserver.k8s.io/v1beta2/3`). Use `pluto`/`kubent` against rendered manifests (FR2).
- **[Med] Resource footprint → Story 1.3 / NFR2.** Module `memory`/`cpus` defaults (`8g`/`4`, `modules/k8s/minicluster/00-variables.tf`) may not reliably boot a heavier 1.33 control-plane under qemu2. Verify node Ready + no OOM after recreate; raise the minikube allocation lever if needed (D10/CM1).
- **[Med] Stale version in docs → Story 3.4.** `docs/project-context.md` still says Kubernetes `v1.29.2` (currently framed as upgrade-target, so acceptable now). Refresh version references once the upgrade lands as part of docs regeneration (FR22).

## Deferred from: code review of 1-2-audit-deprecated-removed-kubernetes-apis (2026-06-19)

- **[High → Story 1.3] Confirm v1.33.10 boots on the 0.6.0-bundled minikube.** Provider 0.6.0 embeds a newer minikube whose `stable` resolves to v1.34.0; our pin is `v1.33.10`. At cluster recreate, verify the bundled minikube fetches kicbase/kubeadm assets for 1.33.10 and the node reports `v1.33.10` (not a silent fallback). [terraform/main/01-cluster.tf:2]
- **[Med → Story 1.3] socket_vmnet/qemu2 runtime check.** `network = socket_vmnet` + `driver = qemu2` are runtime args `terraform validate` cannot verify. Confirm the external `socket_vmnet` daemon/binary version is compatible with the minikube embedded in provider 0.6.0. [terraform/main/01-cluster.tf:8-9]
- **[Low → Story 1.3] Stale state backup schema.** `terraform/main/state/terraform.tfstate.backup` carries the removed `network_plugin` attribute (0.3.x schema). Inert because 1.3 recreates from clean state; remove/ignore if that backup is ever restored under provider 0.6.0.

## Deferred from: Story 1.3 partial completion (2026-06-20)

- **[High → follow-up] Verify GitOps app-sync (airflow/postgres) on the docker cluster.** Story 1.3 verified the cluster (docker, k8s `v1.33.4`, node Ready) + ArgoCD Healthy, but the `argocd` Terraform provider can't reach `argocd.data:443` on the docker driver (node IP `192.168.49.2` not host-routable on macOS). To finish AC#3: run `sudo minikube tunnel -p data` (real terminal) + add `192.168.49.2 argocd.data airflow.data` to `/etc/hosts`, then `terraform apply` → creates the ArgoCD Project + Applications → confirm `airflow` + `postgres` apps Synced/Healthy and no `Pending`/`CrashLoopBackOff`. Then Story 1.3 AC#3/#4 are fully met.
- **[Med → Epic 2 / SM3] Airflow ingress reachability on docker.** Host access to `airflow.data` (and `argocd.data`) needs `minikube tunnel` running on the docker driver. Factor into the Epic 2 cutover / SM3 verification (`https://airflow.data` reachable).
- **[Low] minikube IP may change on recreate.** The `/etc/hosts` mapping targets `192.168.49.2` (current `minikube ip -p data`); re-confirm after any recreate.

## Deferred from: code review of 1-3 / docker switch (2026-06-20) → Story 3.4 (docs)

- **[Med] `terraform/main/readme.md` setup is stale.** It instructs `brew install socket_vmnet` + `sudo brew services start socket_vmnet` (qemu2 era). With the docker driver this is wrong — update the quickstart to the docker driver + note that `minikube tunnel` (+ `/etc/hosts`) is needed for `argocd.data`/`airflow.data` host access.
- **[Low-Med] `terraform/modules/k8s/minicluster/main.tf` doc comment** says "the docker driver does not support the ingress add-on so we advise to use the qemu driver" — now misleading (we run docker with ingress-nginx; host access via tunnel). Update the comment.
- **[Low] Orphaned `network` variable** in `modules/k8s/minicluster` — unused now that `main` doesn't pass `socket_vmnet`. Harmless (default null); keep for module reusability or remove in a cleanup. No action required.

## Deferred from: Story 2.1 (secrets) → Stories 2.5/2.6

- **[RESOLVED in Story 2.6] Wire the generated Postgres password into the Postgres app + remove plaintext.** `module.application_db.auth.password` → `random_password.postgres.result`; the `DATA_PASSWORD` plaintext was removed entirely with the vestigial `extraEnv` block. NFR3 met — no password literal remains in `12-airflow.tf`.
- **[RESOLVED in Story 2.6] Add `depends_on` from the airflow ArgoCD application to the secrets.** `module.application` now `depends_on` all three: `airflow_config_credentials`, `airflow_metadata`, `airflow_result_backend`.
- **[Low → Story 2.6 — declined, kept hardcoded] Consider deriving the metadata `connection` user/db/host from the Postgres app params** instead of hardcoded `mini`/`mini_data_platform`/`postgres-postgresql`. Declined: the module exposes these as a flat `parameters` map (no structured output to reference), so deriving would add fragile string-plumbing for no runtime benefit on this local cluster. Both connection secrets + the DB share the same literals; drift risk is low. Revisit only if the values move to variables.
- **[Low] random_* have no `keepers`** — stable across normal applies; on taint/state-loss they regenerate (fernet rotation would orphan encrypted metadata, but the metadata DB is disposable per PRD). Acceptable for this local cluster; revisit only if persistence matters.

## Deferred from: Story 2.3 (values port) → Stories 2.6 / 2.7

- **[RESOLVED in Story 2.6] Create the `airflow-result-backend` Secret.** `kubernetes_secret.airflow_result_backend` added in `12-airflow.tf` with key `connection = db+postgresql://mini:<pw>@postgres-postgresql.data.svc.cluster.local:5432/mini_data_platform` (the `db+` prefix). (Workers actually persisting results is runtime — Story 2.7.)
- **[High → Story 2.7] SimpleAuth admin password.** `simple_auth_manager_users: admin:admin` sets the user/role; the password auto-generates to a file (the `admin-password` key in `airflow-config-credentials` is unused). At apply, verify login; if a fixed password is wanted, wire it via the documented 3.2 env mechanism from the secret (OQ4/AR12).
- **[RESOLVED in Story 2.6] Fix `module.application` extraEnv nesting.** The double-nested `values.airflow.airflow.extraEnv` block was removed entirely — `DATA_DB`/`DATA_USER`/`DATA_PASSWORD` had no consumer anywhere in the repo (verified by grep across `airflow/ helms/ terraform/`). `module.application` now carries no inline `values`; all config lives in `values.yaml`. This also removed the last `DATA_PASSWORD` plaintext.
- **[Med → Story 2.7] Redis/broker hook-annotated secrets.** The chart's redis-password/broker-url secrets carry `helm.sh/hook: pre-install`; under ArgoCD (no helm hooks) confirm they apply at steady state (workers must reach the broker).
- **[Low → Story 2.7/SM3] base_url https vs ingress TLS.** `config.api.base_url=https://airflow.data` but ingress has no `tls:`; confirm redirects/UI with `minikube tunnel`.

## Deferred from: Story 2.4 (DAG/tooling migration) -> Story 2.7 / operator

- **[Med] Relock `poetry.lock`** in a py3.12 env (`poetry lock`) — still resolves Airflow 2.8 vs pyproject `^3.2.2`. Local dev/tests only; deployed image has 3.2.2.
- **[Med] Run `airflow config lint` + verify new `airflow.sdk` imports resolve + DAG parse** in the Airflow-3 env at the 2.7 cutover (`pre-commit run --hook-stage manual airflow-config-lint`, `airflow dags list`).

### Out-of-scope notes (operator / correct-course, not story-assigned)
- **k8s 1.33 EOL is 2026-06-28** (≈9 days after the 1.33 target was locked). The 1.33 target is fixed by the PRD/Architecture; revisiting it (e.g. toward 1.34) would be a `correct-course` decision, not a dev change.
- **terraform-docs/helm-docs version drift** — the local terraform-docs emits `<br/>` where committed argocd-module READMEs have `<br>`. Recommend a housekeeping commit to align local tool versions with CI so pre-commit doesn't churn unrelated docs.
