resource "minikube_cluster" "cluster" {
  driver       = "hyperkit" # docker does not support DNS addons
  cluster_name = var.name
  cni          = "bridge"
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