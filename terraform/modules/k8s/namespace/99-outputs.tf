output "name" {
  description = "Namespace name"
  value       = kubernetes_namespace.namespace.metadata[0].name
}