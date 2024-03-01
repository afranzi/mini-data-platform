resource "argocd_application" "apps" {
  metadata {
    name      = var.name
    namespace = var.argocd_namespace
  }

  cascade = true

  spec {
    project                = var.project_name
    revision_history_limit = var.history_limit

    source {
      repo_url        = var.repo_url
      path            = var.path
      target_revision = var.target_revision

      helm {
        value_files = var.value_files
      }
    }

    destination {
      server    = var.cluster_name
      namespace = var.namespace
    }
  }
}

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}
