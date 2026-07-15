# Aides post-déploiement (affichées après `terraform apply`).

output "argocd_admin_password_cmd" {
  description = "Commande pour récupérer le mot de passe admin initial d'Argo CD"
  value       = var.install_argocd ? "kubectl ${var.kube_context != "" ? "--context ${var.kube_context} " : ""}-n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d" : "argocd non installé"
}

output "argocd_access_hint" {
  description = "Comment accéder à l'UI Argo CD"
  value       = var.install_argocd ? (var.expose_via_loadbalancer ? "kubectl -n argocd get svc argocd-server (EXTERNAL-IP du LoadBalancer) — login: admin" : "kubectl -n argocd port-forward svc/argocd-server 8080:443 puis https://localhost:8080 — login: admin") : "argocd non installé"
}

output "sonarqube_access_hint" {
  description = "Comment accéder à SonarQube"
  value       = var.install_sonarqube ? (var.expose_via_loadbalancer ? "kubectl -n sonarqube get svc sonarqube-sonarqube (EXTERNAL-IP) :9000 — login initial: admin/admin" : "kubectl -n sonarqube port-forward svc/sonarqube-sonarqube 9000:9000 — login initial: admin/admin") : "sonarqube non installé"
}

output "kibana_access_hint" {
  description = "Comment accéder à Kibana"
  value       = var.install_elk ? (var.expose_via_loadbalancer ? "kubectl -n elk get svc kibana (EXTERNAL-IP) :5601" : "kubectl -n elk port-forward svc/kibana 5601:5601 puis http://localhost:5601") : "elk non installé"
}
