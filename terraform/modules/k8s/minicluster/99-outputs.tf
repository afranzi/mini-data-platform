output "host" {
  description = "The host name for the cluster"
  value       = minikube_cluster.cluster.host
}

output "client_certificate" {
  description = "Client certificate used in cluster"
  value       = minikube_cluster.cluster.client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Client key for cluster"
  value       = minikube_cluster.cluster.client_key
}

output "cluster_ca_certificate" {
  description = "Certificate authority for cluster"
  value       = minikube_cluster.cluster.cluster_ca_certificate
}
