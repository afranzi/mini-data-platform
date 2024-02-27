locals {
  k8s = {
    default_server = "https://kubernetes.default.svc"
  }
}

resource "argocd_project" "main" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  spec {
    description  = var.description
    source_repos = var.repo_urls

    dynamic "destination" {
      for_each = var.namespaces

      content {
        server    = local.k8s.default_server
        namespace = destination.value
      }
    }

    dynamic "cluster_resource_whitelist" {
      for_each = var.cluster_resource_allowlist

      content {
        kind  = cluster_resource_whitelist.value.kind
        group = cluster_resource_whitelist.value.group
      }
    }
  }
}
