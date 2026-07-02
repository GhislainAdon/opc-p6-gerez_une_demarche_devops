output "namespaces" {
  description = "Provisioned namespaces"
  value       = [for ns in kubernetes_namespace.env : ns.metadata[0].name]
}

output "releases" {
  description = "Helm releases status"
  value       = { for k, r in helm_release.microcrm : k => r.status }
}

output "front_urls" {
  description = "Access hint for the frontend services"
  value       = "minikube service microcrm-front -n <dev|staging> --url"
}
