variable "project_name" {
  type        = string
  description = "ArgoCD Project name"
}

variable "repo_url" {
  type        = string
  description = "Repository URL"
}
variable "cluster_name" {
  type        = string
  default     = "https://kubernetes.default.svc"
  description = "Cluster url"
}

variable "argocd_namespace" {
  type        = string
  description = "Namespace where the ArgoCD server has been deployed"
}

variable "namespace" {
  type        = string
  description = "K8s namespace to deploy application"
}

variable "name" {
  type        = string
  description = "Application name"
}

variable "path" {
  type        = string
  default     = ""
  description = "Repository path with helm"
}

variable "chart" {
  type        = string
  default     = null
  description = "Repository path with helm"
}

variable "target_revision" {
  type        = string
  default     = "HEAD"
  description = "Target revision to retrieve from Git"
}

variable "value_files" {
  type        = list(string)
  default     = ["values.yaml"]
  description = "Helm value files"
}

variable "history_limit" {
  type        = number
  default     = 3
  description = "History limit"
}

variable "parameters" {
  type        = map(string)
  default     = {}
  description = "Helm parameters which are passed to the helm template command upon manifest generation"
}

variable "values" {
  type        = any
  default     = null
  description = "Helm values which are passed to the helm template command upon manifest generation"
}
