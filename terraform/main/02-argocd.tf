module "argocd" {
  source        = "../modules/k8s/argocd/server"
  argocd_domain = "argocd.data"
  depends_on    = [module.cluster]
}

provider "argocd" {
  server_addr = "${module.argocd.argocd_server}:443"
  username    = "admin"
  password    = module.argocd.argocd_token
  grpc_web    = true
  insecure    = true
}

locals {
  namespaces = {
    data = "data"
  }
  argo_examples_repo = "https://github.com/argoproj/argocd-example-apps.git"
}

module "project" {
  source                     = "../modules/k8s/argocd/project"
  cluster_resource_allowlist = [{ group : "*", kind : "*" }]
  description                = "Data Platform projects"
  name                       = "mini-data-platform"
  namespaces                 = [local.namespaces.data]
  repo_urls                  = [local.argo_examples_repo]
  depends_on                 = [module.argocd]
  namespace                  = module.argocd.namespace
}

module "application" {
  source           = "../modules/k8s/argocd/application"
  name             = "guestbook"
  namespace        = local.namespaces.data
  project_name     = module.project.name
  repo_url         = local.argo_examples_repo
  path             = "helm-guestbook"
  argocd_namespace = module.argocd.namespace
}

resource "kubernetes_ingress_v1" "app_ingress" {
  metadata {
    name      = "app-ingress"
    namespace = local.namespaces.data
    annotations = {}
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      http {
        path {
          backend {
            service {
              name = "guestbook-helm-guestbook"
              port {
                name = "http"
              }
            }
          }
        }
      }
      host = "guestbook.data"
    }
  }
}