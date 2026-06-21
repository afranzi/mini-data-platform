# Runbook — Clean-State Bring-Up (k8s 1.33 + Airflow 3)

How to stand up the entire `mini-data-platform` (minikube k8s 1.33 + ArgoCD + Postgres + Airflow 3) from nothing, reproducibly. Verified end-to-end in Story 3.1 (2026-06-21) on the docker driver / macOS.

> **Platform reproducibility (NFR1/SM1):** once the host prerequisites below are met, the platform comes up with **no manual workload steps** — ArgoCD auto-reconciles all Applications (automated `syncPolicy`). The only manual interjections are host-level (the `minikube tunnel`, which `sudo` requires a real terminal for) and a documented two-phase `terraform apply` to bootstrap the ArgoCD provider.

## Host prerequisites (one-time / environment)

1. **Docker** running (the minikube `docker` driver — `qemu2`/`vfkit` are IT-firewall-blocked on this host).
2. **`/etc/hosts`** maps the ingress hostnames to **`127.0.0.1`** (the docker-driver `minikube tunnel` binds localhost, **not** the node IP):
   ```
   127.0.0.1 argocd.data airflow.data
   ```
3. **`minikube tunnel`** running in a **real terminal** (sudo can't prompt through tooling):
   ```
   sudo minikube tunnel -p data
   ```
   Needed for the ArgoCD Terraform provider to reach `argocd.data:443` and for browser/API access to `airflow.data`. It can only run **after** the cluster + ingress exist (see Phase A→B), and must be **restarted after any cluster recreate** (the process survives but loses its port binding).

## Bring-up sequence

From `terraform/main/`:

### Phase A — cluster + ArgoCD (no tunnel needed)
The `argocd` Terraform provider is configured from `module.argocd` outputs, so it can't be configured before ArgoCD exists (chicken-and-egg). Bootstrap the cluster + ArgoCD first with `-target` (the kubernetes/helm providers use the kubeconfig, no tunnel required):
```
terraform apply -target=module.cluster -target=module.argocd
```
- **Known race:** ArgoCD's helm release creates an Ingress that calls the `ingress-nginx` admission webhook; on a fresh cluster the controller may not be Ready yet → `failed calling webhook ... connection refused`. **Re-run the same command** once `kubectl -n ingress-nginx get pods` shows the controller `Running` (a few seconds).

### Phase B — start the tunnel, then apply everything
1. Start (or restart) the tunnel against the now-running cluster:
   ```
   sudo pkill -f "minikube tunnel" ; sudo minikube tunnel -p data
   ```
   Confirm reachable: `argocd.data:443` should accept connections.
2. Apply the rest (Project + Applications + TF-managed secrets):
   ```
   terraform apply
   ```

### Result — automatic reconciliation
ArgoCD then **self-syncs** both Applications (automated `syncPolicy { prune, self_heal }` on the generic application module) — no manual `argocd app sync` / `kubectl patch`. Expect (images pull on first run, ~5 min):
- `postgres` → Synced/Healthy
- `airflow` → Synced/Healthy; components: `api-server`, `scheduler`, standalone `dag-processor`, `triggerer`, `worker`, `redis`; the `run-airflow-migrations` sync-hook Job Completes.

## Verify
```
kubectl --context data -n argocd get applications          # both Synced/Healthy
kubectl --context data -n data get pods                    # all Running, migrate Completed
# health (v2 path) + DAG parse:
curl -sk https://airflow.data/api/v2/monitor/health        # all subsystems "healthy"
kubectl --context data -n data exec deploy/airflow-scheduler -c scheduler -- airflow dags list-import-errors   # "No data found"
```

## Log in to the Airflow UI
SimpleAuth admin (`admin`); the password is **auto-generated and ephemeral** (regenerates on every api-server restart). Retrieve the current one:
```
kubectl --context data -n data logs deploy/airflow-api-server -c api-server | grep "Password for user 'admin'"
```
Browse `https://airflow.data` (HTTP-served over the tunnel; `base_url=https` is cosmetic — no ingress TLS).

## Teardown
```
terraform destroy
```
- **Known race:** the first pass may fail deleting the ArgoCD **project** ("referenced by N applications") because ArgoCD cascade-deletes the Applications asynchronously after Terraform drops them from state. **Re-run `terraform destroy`** to finish (project + ArgoCD + cluster). ArgoCD CRDs are intentionally retained by helm resource policy.

## Notes / known follow-ups
- `random_*` secrets (fernet, JWT, api-secret, admin, postgres) regenerate on recreate (no `keepers`). Harmless: the metadata DB is disposable, so fernet rotation has nothing to orphan.
- The two `terraform apply` retry points (ingress-nginx readiness; destroy project race) are timing artifacts, not config errors. A future hardening could add explicit waits/`depends_on` (tracked in deferred-work).
- Host access on the docker driver always needs the tunnel; there is no host-routable node IP on macOS.
