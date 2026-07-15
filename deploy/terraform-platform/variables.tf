# --- Ciblage du cluster ---
variable "kube_config_path" {
  description = "Chemin du kubeconfig"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Contexte kube à cibler (ex. ARN du contexte EKS ; vide = contexte courant)"
  type        = string
  default     = ""
}

variable "expose_via_loadbalancer" {
  description = "Exposer les UIs via un Service LoadBalancer (cloud) plutôt que ClusterIP"
  type        = bool
  default     = true
}

# --- Flags d'installation (outillage optionnel) ---
variable "install_argocd" {
  description = "Installer Argo CD (moteur GitOps)"
  type        = bool
  default     = true
}

variable "install_sonarqube" {
  description = "Installer SonarQube (+ PostgreSQL embarqué en démo)"
  type        = bool
  default     = false
}

variable "install_elk" {
  description = "Installer Elasticsearch + Kibana"
  type        = bool
  default     = false
}

# --- Argo CD ---
variable "argocd_chart_version" {
  description = "Version du chart argo-cd (argoproj/argo-helm)"
  type        = string
  default     = "7.6.12"
}

variable "argocd_applications" {
  description = "Manifests d'Applications Argo CD à appliquer (dans deploy/argocd/)"
  type        = list(string)
  default     = ["application-dev.yaml", "application-test.yaml", "application-prod.yaml"]
}

variable "gitlab_repo_url" {
  description = "URL du dépôt Git suivi par Argo CD"
  type        = string
  default     = "https://gitlab.com/openclassrooms7804126/opc-p6-gerez_une_demarche_devops.git"
}

variable "gitlab_repo_token" {
  description = "Jeton read_repository pour qu'Argo CD lise le dépôt privé (TF_VAR_gitlab_repo_token, jamais commité). Vide = repo public/déjà configuré."
  type        = string
  default     = ""
  sensitive   = true
}

# --- SonarQube ---
variable "sonarqube_chart_version" {
  description = "Version du chart sonarqube (SonarSource)"
  type        = string
  default     = "2025.1.0"
}

variable "sonarqube_monitoring_passcode" {
  description = "Passcode d'endpoint monitoring SonarQube (requis par le chart)"
  type        = string
  default     = "orion-monitoring"
  sensitive   = true
}

# --- ELK ---
variable "elasticsearch_chart_version" {
  description = "Version du chart bitnami/elasticsearch"
  type        = string
  default     = "21.4.6"
}

variable "kibana_chart_version" {
  description = "Version du chart bitnami/kibana"
  type        = string
  default     = "11.2.24"
}
