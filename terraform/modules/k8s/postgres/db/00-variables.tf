variable "name" {
  type        = string
  description = "Postgres Instance name"
  default     = "argocd"
}

variable "namespace" {
  type        = string
  description = "K8s namespace to use"
  default     = "data"
}

variable "postgres_version" {
  type        = string
  description = "Docker image tag to use for deployment - https://github.com/argoproj/argo-cd/releases"
  default     = "v2.10.1"
}

variable "postgres_helm_chart_version" {
  default     = "6.4.0"
  type        = string
  description = "ArgoCD Helm version at https://github.com/argoproj/argo-helm/releases"
}

variable "postgres_domain" {
  type        = string
  description = "ArgoCD DNS name"
}
