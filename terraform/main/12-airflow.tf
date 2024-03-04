locals {
  namespace           = "data"
  airflow_helm_repo   = "https://github.com/afranzi/mini-data-platform.git"
  bitnami_helm_charts = "https://charts.bitnami.com/bitnami"
}

module "namespace" {
  source    = "../modules/k8s/namespace"
  namespace = local.namespace
}

module "project" {
  source                     = "../modules/k8s/argocd/project"
  cluster_resource_allowlist = [{ group : "*", kind : "*" }]
  description                = "Data Platform projects"
  name                       = "mini-data-platform"
  namespaces                 = [local.namespace]
  repo_urls                  = [local.airflow_helm_repo, local.bitnami_helm_charts]
  depends_on                 = [module.argocd]
  namespace                  = module.argocd.namespace
}


module "application_db" {
  source           = "../modules/k8s/argocd/application"
  name             = "postgres"
  argocd_namespace = module.argocd.namespace
  namespace        = module.namespace.name
  project_name     = module.project.name
  repo_url         = local.bitnami_helm_charts
  chart            = "postgresql"
  target_revision  = "14.2.4"

  parameters = {
    "auth.database" : "mini_data_platform"
    "auth.username" : "mini"
    "auth.password" : "data"
  }
}


module "application" {
  source           = "../modules/k8s/argocd/application"
  name             = "airflow"
  argocd_namespace = module.argocd.namespace
  namespace        = module.namespace.name
  project_name     = module.project.name
  repo_url         = local.airflow_helm_repo
  path             = "helms/airflow"
  target_revision  = "HEAD"

  values = {
    airflow = {
      airflow = {
        extraEnv = [
          { name : "DATA_DB", value : "mini_data_platform" },
          { name : "DATA_USER", value : "mini" },
          { name : "DATA_PASSWORD", value : "data" },
        ]
      }
    }
  }
}
