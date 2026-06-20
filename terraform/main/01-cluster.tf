provider "minikube" {
  kubernetes_version = "v1.33.4"
}

module "cluster" {
  source = "../modules/k8s/minicluster"
  name   = "data"
  driver = "docker"
  # docker driver: qemu2/vfkit VM SSH is blocked by the host IT firewall, so the
  # docker driver is the only working option here. Uses docker networking (no
  # socket_vmnet). k8s pinned to v1.33.4 — minikube's latest supported 1.33 patch.
  # See sprint-change-proposal-2026-06-20. NOTE: docker driver on macOS needs
  # `minikube tunnel` for host ingress reachability (airflow.data).
}

provider "kubernetes" {
  host = module.cluster.host

  client_certificate     = module.cluster.client_certificate
  client_key             = module.cluster.client_key
  cluster_ca_certificate = module.cluster.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = module.cluster.host
    client_certificate     = module.cluster.client_certificate
    client_key             = module.cluster.client_key
    cluster_ca_certificate = module.cluster.cluster_ca_certificate
  }
}
