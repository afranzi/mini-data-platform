output "name" {
  description = "Project name"
  value       = argocd_project.main.metadata[0].name
}