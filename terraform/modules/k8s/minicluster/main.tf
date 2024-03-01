/**
 * # MiniCluster
 * This module aims to deploy a Kubernetes cluster by using [minikube](https://minikube.sigs.k8s.io/)
 *
 * ## Requirements
 * Since we will be deploying ArgoCD & Airflow in the local k8s cluster, we should provide at least 8GB & 4 CPUs.
 *
 * !!! tip "minikube drivers"
 *     The **docker** driver does not support the ingress add-on so we advice to use the
 *     [qemu](https://minikube.sigs.k8s.io/docs/drivers/qemu/) driver in M1 & M2 Macs, since
 *     [hyperkit](https://minikube.sigs.k8s.io/docs/drivers/hyperkit/) is not supported in arm architecture.
 */
