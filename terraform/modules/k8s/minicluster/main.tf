/**
 * # MiniCluster
 * This module aims to deploy a Kubernetes cluster by using [minikube](https://minikube.sigs.k8s.io/)
 *
 * ## Requirements
 * Since we will be deploying ArgoCD & Airflow in the local k8s cluster, we should provide at least 8GB & 4 CPUs.
 *
 * !!! tip "minikube drivers"
 *     This platform uses the **docker** driver with the ingress-nginx add-on (the qemu2/vfkit VM
 *     drivers are blocked by the corporate firewall on the target host). On the docker driver the
 *     node IP is not host-routable on macOS, so host access to `*.data` ingress hosts needs
 *     `sudo minikube tunnel -p data` + an `/etc/hosts` entry pointing them at `127.0.0.1`.
 */
