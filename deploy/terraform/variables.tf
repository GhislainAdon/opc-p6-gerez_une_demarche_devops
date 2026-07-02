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

variable "registry_server" {
  description = "Container registry host"
  type        = string
  default     = "registry.gitlab.com"
}

variable "registry_user" {
  description = "Registry username (deploy token user or oauth2)"
  type        = string
  default     = "oauth2"
}

variable "registry_token" {
  description = "Registry access token — pass via TF_VAR_registry_token, never commit"
  type        = string
  sensitive   = true
}

variable "image_tag" {
  description = "Image tag to deploy (e.g. guide-a1b2c3d4 from the CI pipeline)"
  type        = string
  default     = "latest"
}
