variable "kube_context" {
  description = "Kubernetes context to target (Minikube by default)"
  type        = string
  default     = "minikube"
}

variable "environments" {
  description = "Environments to provision (one namespace + Helm release each)"
  type        = list(string)
  default     = ["dev", "staging"]
}

variable "image_tag" {
  description = "Image tag to deploy (e.g. guide-a1b2c3d4 from the CI pipeline)"
  type        = string
  default     = "latest"
}
