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
      chart           = var.chart
      target_revision = var.target_revision

      helm {
        value_files = var.value_files

        values = var.values != null ? yamlencode(var.values) : null

        dynamic "parameter" {
          for_each = var.parameters
          content {
            name  = parameter.key
            value = parameter.value
          }
        }
      }
    }

    destination {
      server    = var.cluster_name
      namespace = var.namespace
    }

    # Automated reconciliation: ArgoCD syncs the app to the Git desired state on
    # its own (no manual `argocd app sync` / `kubectl patch operation`). prune
    # removes resources dropped from Git; self_heal reverts out-of-band drift.
    sync_policy {
      dynamic "automated" {
        for_each = var.automated_sync ? [1] : []
        content {
          prune       = true
          self_heal   = true
          allow_empty = false
        }
      }

      sync_options = var.sync_options
    }
  }
}
