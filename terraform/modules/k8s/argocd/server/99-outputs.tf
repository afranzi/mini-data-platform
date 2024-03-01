output "argocd_token" {
  description = "ArgoCD Token"
  value       = data.kubernetes_secret.argo_token.data.password
}

output "argocd_server" {
  description = "ArgoCD Server Addr"
  value       = var.argocd_domain
}

output "namespace" {
  description = "K8s namespace where ArgoCD server has been deployed"
  value       = kubernetes_namespace.argocd.metadata[0].name
}
