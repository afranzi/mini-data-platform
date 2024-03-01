terraform {
  required_version = ">= 1.7.4"
  required_providers {
    # https://registry.terraform.io/providers/oboukili/argocd/
    argocd = {
      source  = "oboukili/argocd"
      version = "6.0.3"
    }
    # https://registry.terraform.io/providers/hashicorp/kubernetes
    kubernetes = {
      version = "~> 2.26.0"
      source  = "hashicorp/kubernetes"
    }
  }
}
