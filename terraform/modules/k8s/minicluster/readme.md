<!-- BEGIN_TF_DOCS -->
# MiniCluster
This module aims to deploy a Kubernetes cluster by using [minikube](https://minikube.sigs.k8s.io/)

## Requirements
Since we will be deploying ArgoCD & Airflow in the local k8s cluster, we should provide at least 8GB & 4 CPUs.

!!! tip "minikube drivers"
    The **docker** driver does not support the ingress add-on so we advice to use the
    [qemu](https://minikube.sigs.k8s.io/docs/drivers/qemu/) driver in M1 & M2 Macs, since
    [hyperkit](https://minikube.sigs.k8s.io/docs/drivers/hyperkit/) is not supported in arm architecture.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.4 |
| <a name="requirement_minikube"></a> [minikube](#requirement\_minikube) | ~> 0.3.10 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_minikube"></a> [minikube](#provider\_minikube) | ~> 0.3.10 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [minikube_cluster.cluster](https://registry.terraform.io/providers/scott-the-programmer/minikube/latest/docs/resources/cluster) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cpus"></a> [cpus](#input\_cpus) | Amount of CPUs to allocate to Kubernetes | `number` | `4` | no |
| <a name="input_driver"></a> [driver](#input\_driver) | Minikube driver | `string` | n/a | yes |
| <a name="input_memory"></a> [memory](#input\_memory) | Amount of RAM to allocate to Kubernetes | `string` | `"8g"` | no |
| <a name="input_name"></a> [name](#input\_name) | Cluster name | `string` | n/a | yes |
| <a name="input_network"></a> [network](#input\_network) | Network to run minikube with | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_client_certificate"></a> [client\_certificate](#output\_client\_certificate) | Client certificate used in cluster |
| <a name="output_client_key"></a> [client\_key](#output\_client\_key) | Client key for cluster |
| <a name="output_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#output\_cluster\_ca\_certificate) | Certificate authority for cluster |
| <a name="output_host"></a> [host](#output\_host) | The host name for the cluster |
<!-- END_TF_DOCS -->