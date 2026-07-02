# Infrastructure-as-Code — Minikube deployment of the Orion Full-Stack app.
#
# Creates the dev and staging namespaces and installs the microcrm Helm chart
# in each, with environment-specific values.
#
#   minikube start
#   terraform init && terraform plan && terraform apply
#
# State stays local (.tfstate gitignored). No cloud credentials involved.

terraform {
  required_version = ">= 1.5"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = var.kube_context
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = var.kube_context
  }
}

resource "kubernetes_namespace" "env" {
  for_each = toset(var.environments)
  metadata {
    name = each.key
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      project                        = "orion-microcrm"
    }
  }
}

resource "kubernetes_secret" "registry" {
  for_each = toset(var.environments)
  metadata {
    name      = "gitlab-registry"
    namespace = kubernetes_namespace.env[each.key].metadata[0].name
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (var.registry_server) = {
          username = var.registry_user
          password = var.registry_token
          auth     = base64encode("${var.registry_user}:${var.registry_token}")
        }
      }
    })
  }
}

resource "helm_release" "microcrm" {
  depends_on = [kubernetes_secret.registry]
  for_each  = toset(var.environments)
  name      = "microcrm"
  namespace = kubernetes_namespace.env[each.key].metadata[0].name
  chart     = "${path.module}/../helm/microcrm"

  values = [
    file("${path.module}/../helm/microcrm/values-${each.key}.yaml")
  ]

  set {
    name  = "image.tag"
    value = var.image_tag
  }

  timeout = 300
  wait    = true
}
