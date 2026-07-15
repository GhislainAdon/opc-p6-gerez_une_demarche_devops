# Infrastructure-as-Code — PLATEFORME (outillage) pour un cluster Kubernetes cloud.
#
# Installe, de façon déclarative et OPTIONNELLE (flags), l'outillage nécessaire à
# la chaîne quand on déploie sur un vrai cluster (ex. EKS) au lieu du poste local :
#   - Argo CD        (moteur GitOps)         -> var.install_argocd
#   - SonarQube      (quality gate)          -> var.install_sonarqube
#   - Stack ELK      (observabilité)         -> var.install_elk
#
# En local (démo), on garde `scripts/secret/bootstrap.sh` (plus rapide, éphémère).
# Ce module vise le CLOUD. Il cible le contexte kube courant :
#
#   eksctl create cluster --name orion --region eu-west-3 ...
#   aws eks update-kubeconfig --name orion --region eu-west-3
#   terraform init
#   terraform apply -var kube_context=<arn-du-contexte-eks> \
#     -var install_argocd=true -var install_sonarqube=true -var install_elk=true \
#     -var gitlab_repo_token=<PAT read_repository>
#
# ⚠️ Correct-par-construction mais NON appliqué sur un EKS réel dans ce projet
#    (seul le chemin local Docker Desktop/Minikube est validé en direct).

terraform {
  required_version = ">= 1.5"
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.31" }
    helm       = { source = "hashicorp/helm", version = "~> 2.14" }
    null       = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "kubernetes" {
  config_path    = var.kube_config_path
  config_context = var.kube_context
}

provider "helm" {
  kubernetes {
    config_path    = var.kube_config_path
    config_context = var.kube_context
  }
}

# ------------------------------------------------------------------ Argo CD
resource "helm_release" "argocd" {
  count            = var.install_argocd ? 1 : 0
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  timeout          = 600
  wait             = true
  # Sur cloud, exposer l'UI via un LoadBalancer (sinon port-forward).
  set {
    name  = "server.service.type"
    value = var.expose_via_loadbalancer ? "LoadBalancer" : "ClusterIP"
  }
}

# Identifiants de connexion au dépôt privé GitLab pour qu'Argo CD puisse le tirer.
resource "kubernetes_secret" "argocd_repo" {
  count = var.install_argocd && var.gitlab_repo_token != "" ? 1 : 0
  metadata {
    name      = "repo-opc-p6"
    namespace = "argocd"
    labels    = { "argocd.argoproj.io/secret-type" = "repository" }
  }
  data = {
    type     = "git"
    url      = var.gitlab_repo_url
    username = "oauth2"
    password = var.gitlab_repo_token
  }
  depends_on = [helm_release.argocd]
}

# Applique les Applications Argo CD (dev/test/prod) après l'installation du chart.
# On passe par kubectl (local-exec) pour éviter la validation des CRD au plan.
resource "null_resource" "argocd_apps" {
  count = var.install_argocd ? 1 : 0
  triggers = {
    manifests = join(",", var.argocd_applications)
    context   = coalesce(var.kube_context, "current")
  }
  provisioner "local-exec" {
    command = join(" && ", [
      for app in var.argocd_applications :
      "kubectl ${var.kube_context != "" ? "--context ${var.kube_context}" : ""} apply -f ${path.module}/../argocd/${app}"
    ])
  }
  depends_on = [helm_release.argocd, kubernetes_secret.argocd_repo]
}

# ---------------------------------------------------------------- SonarQube
# Chart officiel SonarSource. PostgreSQL embarqué (sous-chart Bitnami) activé pour
# une démo cloud ; en production, pointer une base managée (RDS) via sonar values.
resource "helm_release" "sonarqube" {
  count            = var.install_sonarqube ? 1 : 0
  name             = "sonarqube"
  namespace        = "sonarqube"
  create_namespace = true
  repository       = "https://SonarSource.github.io/helm-chart-sonarqube"
  chart            = "sonarqube"
  version          = var.sonarqube_chart_version
  timeout          = 900
  wait             = true

  set {
    name  = "community.enabled"
    value = "true"
  }
  set {
    name  = "postgresql.enabled" # DB embarquée (démo). RDS en prod.
    value = "true"
  }
  set {
    name  = "monitoringPasscode"
    value = var.sonarqube_monitoring_passcode
  }
  set {
    name  = "service.type"
    value = var.expose_via_loadbalancer ? "LoadBalancer" : "ClusterIP"
  }
}

# --------------------------------------------------------------------- ELK
# Elasticsearch + Kibana (Bitnami). NB : sur cloud, l'ingestion des logs se fait
# via un collecteur (Fluent Bit → Elasticsearch), pas via le driver GELF/Logstash
# local — à adapter selon la plateforme (voir deploy/README.md).
resource "helm_release" "elasticsearch" {
  count            = var.install_elk ? 1 : 0
  name             = "elasticsearch"
  namespace        = "elk"
  create_namespace = true
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "elasticsearch"
  version          = var.elasticsearch_chart_version
  timeout          = 900
  wait             = true
  set {
    name  = "security.enabled" # démo ; TLS/creds en prod
    value = "false"
  }
}

resource "helm_release" "kibana" {
  count      = var.install_elk ? 1 : 0
  name       = "kibana"
  namespace  = "elk"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "kibana"
  version    = var.kibana_chart_version
  timeout    = 600
  wait       = true
  set {
    name  = "elasticsearch.hosts[0]"
    value = "elasticsearch.elk.svc.cluster.local"
  }
  set {
    name  = "elasticsearch.port"
    value = "9200"
  }
  set {
    name  = "service.type"
    value = var.expose_via_loadbalancer ? "LoadBalancer" : "ClusterIP"
  }
  depends_on = [helm_release.elasticsearch]
}
