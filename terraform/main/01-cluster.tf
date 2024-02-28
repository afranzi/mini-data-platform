provider "minikube" {
  kubernetes_version = "v1.29.2"
}

module "cluster" {
  source = "../modules/k8s/minicluster"
  name   = "data"
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