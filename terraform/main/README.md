# main

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.4 |
| <a name="requirement_argocd"></a> [argocd](#requirement\_argocd) | 6.0.3 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.12.1 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.26.0 |
| <a name="requirement_minikube"></a> [minikube](#requirement\_minikube) | ~> 0.3.10 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_application"></a> [application](#module\_application) | ../modules/k8s/argocd/application | n/a |
| <a name="module_argocd"></a> [argocd](#module\_argocd) | ../modules/k8s/argocd/server | n/a |
| <a name="module_cluster"></a> [cluster](#module\_cluster) | ../modules/k8s/minicluster | n/a |
| <a name="module_project"></a> [project](#module\_project) | ../modules/k8s/argocd/project | n/a |

## Resources

No resources.

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
