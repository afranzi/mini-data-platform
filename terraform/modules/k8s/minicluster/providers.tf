terraform {
  required_version = ">= 1.7.4"
  required_providers {
    # https://registry.terraform.io/providers/scott-the-programmer/minikube
    minikube = {
      version = "~> 0.3.10"
      source  = "scott-the-programmer/minikube"
    }
  }
}