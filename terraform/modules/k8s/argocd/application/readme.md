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
| [argocd_application.apps](https://registry.terraform.io/providers/oboukili/argocd/6.0.3/docs/resources/application) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_argocd_namespace"></a> [argocd\_namespace](#input\_argocd\_namespace) | Namespace where the ArgoCD server has been deployed | `string` | n/a | yes |
| <a name="input_chart"></a> [chart](#input\_chart) | Repository path with helm | `string` | `null` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster url | `string` | `"https://kubernetes.default.svc"` | no |
| <a name="input_history_limit"></a> [history\_limit](#input\_history\_limit) | History limit | `number` | `3` | no |
| <a name="input_name"></a> [name](#input\_name) | Application name | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | K8s namespace to deploy application | `string` | n/a | yes |
| <a name="input_parameters"></a> [parameters](#input\_parameters) | Helm parameters which are passed to the helm template command upon manifest generation | `map(string)` | `{}` | no |
| <a name="input_path"></a> [path](#input\_path) | Repository path with helm | `string` | `""` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | ArgoCD Project name | `string` | n/a | yes |
| <a name="input_repo_url"></a> [repo\_url](#input\_repo\_url) | Repository URL | `string` | n/a | yes |
| <a name="input_target_revision"></a> [target\_revision](#input\_target\_revision) | Target revision to retrieve from Git | `string` | `"HEAD"` | no |
| <a name="input_value_files"></a> [value\_files](#input\_value\_files) | Helm value files | `list(string)` | <pre>[<br>  "values.yaml"<br>]</pre> | no |
| <a name="input_values"></a> [values](#input\_values) | Helm values which are passed to the helm template command upon manifest generation | `any` | `null` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
