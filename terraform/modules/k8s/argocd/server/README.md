# server

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.4 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.12.1 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.26.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 2.12.1 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 2.26.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.argocd](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.argocd](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.argo_token](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/secret) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_argocd_domain"></a> [argocd\_domain](#input\_argocd\_domain) | ArgoCD DNS name | `string` | n/a | yes |
| <a name="input_argocd_helm_chart_version"></a> [argocd\_helm\_chart\_version](#input\_argocd\_helm\_chart\_version) | ArgoCD Helm version at https://github.com/argoproj/argo-helm/releases | `string` | `"6.4.0"` | no |
| <a name="input_argocd_version"></a> [argocd\_version](#input\_argocd\_version) | Docker image tag to use for deployment - https://github.com/argoproj/argo-cd/releases | `string` | `"v2.10.1"` | no |
| <a name="input_name"></a> [name](#input\_name) | ArgoCD Cluster name | `string` | `"argocd"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | K8s namespace to use | `string` | `"argocd"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_argocd_server"></a> [argocd\_server](#output\_argocd\_server) | ArgoCD Server Addr |
| <a name="output_argocd_token"></a> [argocd\_token](#output\_argocd\_token) | ArgoCD Token |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | K8s namespace where ArgoCD server has been deployed |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
