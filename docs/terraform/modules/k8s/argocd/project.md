<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.4 |
| <a name="requirement_argocd"></a> [argocd](#requirement\_argocd) | 6.0.3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_argocd"></a> [argocd](#provider\_argocd) | 6.0.3 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [argocd_project.main](https://registry.terraform.io/providers/oboukili/argocd/6.0.3/docs/resources/project) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_resource_allowlist"></a> [cluster\_resource\_allowlist](#input\_cluster\_resource\_allowlist) | Resource allowlist | <pre>list(object({<br>    group : string<br>    kind : string<br>  }))</pre> | n/a | yes |
| <a name="input_description"></a> [description](#input\_description) | Project description | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Project name | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Project namespace | `string` | n/a | yes |
| <a name="input_namespaces"></a> [namespaces](#input\_namespaces) | K8s namespaces where the project would be able to access | `list(string)` | n/a | yes |
| <a name="input_repo_urls"></a> [repo\_urls](#input\_repo\_urls) | Git Repository URLs that will interact with the project | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_name"></a> [name](#output\_name) | Project name |
<!-- END_TF_DOCS -->
