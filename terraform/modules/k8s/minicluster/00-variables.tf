variable "name" {
  type        = string
  description = "Cluster name"
}

variable "driver" {
  type        = string
  description = "Minikube driver"
}

variable "network" {
  type        = string
  description = "Network to run minikube with"
  default     = null
}

variable "memory" {
  type        = string
  description = "Amount of RAM to allocate to Kubernetes"
  default     = "8g"
}

variable "cpus" {
  type        = number
  description = "Amount of CPUs to allocate to Kubernetes"
  default     = 4
}