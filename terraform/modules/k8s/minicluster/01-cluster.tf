resource "minikube_cluster" "cluster" {
  driver       = var.driver # Note: docker does not support DNS addons
  cluster_name = var.name
  cni          = "bridge"
  network      = var.network
  memory       = var.memory
  cpus         = var.cpus
  addons       = [
    "default-storageclass",
    "storage-provisioner",
    # https://minikube.sigs.k8s.io/docs/handbook/addons/ingress-dns/
    "ingress",
    "ingress-dns",
    "metrics-server",
  ]
}