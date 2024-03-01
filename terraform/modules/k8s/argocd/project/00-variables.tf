variable "name" {
  type        = string
  description = "Project name"
}

variable "description" {
  type        = string
  description = "Project description"
}

variable "namespace" {
  type        = string
  description = "Project namespace"
}

variable "namespaces" {
  type        = list(string)
  description = "K8s namespaces where the project would be able to access"
}

variable "cluster_resource_allowlist" {
  description = "Resource allowlist"
  type = list(object({
    group : string
    kind : string
  }))
}

variable "repo_urls" {
  type        = list(string)
  description = "Git Repository URLs that will interact with the project"
}
