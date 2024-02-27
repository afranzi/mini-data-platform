terraform {
  required_version = ">= 1.7.4"
  required_providers {
    # https://registry.terraform.io/providers/oboukili/argocd/
    argocd = {
      source  = "oboukili/argocd"
      version = "6.0.3"
    }
  }
}