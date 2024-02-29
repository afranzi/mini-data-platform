variable "name" {
  type        = string
  description = "Cluster name"
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