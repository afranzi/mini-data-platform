locals {
  namespace = "data"
  helm_repo = "https://github.com/afranzi/mini-data-platform.git"
}

module "project" {
  source                     = "../modules/k8s/argocd/project"
  cluster_resource_allowlist = [{ group : "*", kind : "*" }]
  description                = "Data Platform projects"
  name                       = "mini-data-platform"
  namespaces                 = [local.namespace]
  repo_urls                  = [local.helm_repo]
  depends_on                 = [module.argocd]
  namespace                  = module.argocd.namespace
}

module "application" {
  source           = "../modules/k8s/argocd/application"
  name             = "airflow"
  namespace        = local.namespace
  project_name     = module.project.name
  repo_url         = local.helm_repo
  path             = "helms/airflow"
  target_revision  = "HEAD"
  argocd_namespace = module.argocd.namespace
}