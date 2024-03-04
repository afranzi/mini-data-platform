terraform {
  required_version = ">= 1.7.4"
  required_providers {
    # https://registry.terraform.io/providers/hashicorp/kubernetes
    kubernetes = {
      version = "~> 2.26.0"
      source  = "hashicorp/kubernetes"
    }
  }
}
