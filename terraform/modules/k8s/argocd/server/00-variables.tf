variable "name" {
  type        = string
  description = "ArgoCD Cluster name"
  default     = "argocd"
}

variable "namespace" {
  type        = string
  description = "K8s namespace to use"
  default     = "argocd"
}

variable "argocd_version" {
  type        = string
  description = "Docker image tag to use for deployment - https://github.com/argoproj/argo-cd/releases"
  default     = "v2.10.1"
}

variable "argocd_helm_chart_version" {
  default     = "6.4.0"
  type        = string
  description = "ArgoCD Helm version at https://github.com/argoproj/argo-helm/releases"
}

variable "argocd_domain" {
  type        = string
  description = "ArgoCD DNS name"
}