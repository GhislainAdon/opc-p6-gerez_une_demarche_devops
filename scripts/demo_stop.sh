#!/usr/bin/env bash
# demo_stop.sh — INVERSE de scripts/secret/bootstrap.sh : démonte l'environnement
# de démo et LIBÈRE LES PORTS, pour pouvoir relancer le bootstrap proprement sans
# erreurs de conflit (port 9000 déjà pris, conteneur/namespace existant, etc.).
# Contient zéro secret → versionnable sans risque.
#
# Usage : bash scripts/demo_stop.sh
# Pour libérer TOUTE la RAM ensuite : arrêter Docker Desktop.
set -u
KC="kubectl --context docker-desktop"
log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

# --- SonarQube : supprime le conteneur -> libère le port 9000 ---
log "SonarQube : arrêt + suppression du conteneur (port 9000)"
docker rm -f sonarqube orion-sonarqube >/dev/null 2>&1 && echo "  conteneur(s) Sonar supprimé(s)" || echo "  (aucun conteneur Sonar)"

# --- Tunnel Cloudflare : ferme le process ---
log "Tunnel cloudflared : fermeture"
if command -v taskkill >/dev/null 2>&1; then
  taskkill //IM cloudflared.exe //F >/dev/null 2>&1 && echo "  tunnel fermé" || echo "  (aucun cloudflared)"
else
  pkill -f "cloudflared tunnel" 2>/dev/null && echo "  tunnel fermé" || echo "  (aucun cloudflared)"
fi
rm -f scripts/secret/cloudflared.pid scripts/secret/cloudflared*.log scripts/secret/cf*.log 2>/dev/null || true

# --- Argo CD + app : supprime les namespaces -> libère les NodePorts ---
# (argocd-server 30901, front dev/test/prod 30080/81/82) et retire Argo CD +
# l'application. Le bootstrap les recrée intégralement au prochain run.
log "Argo CD + application : suppression des namespaces (libère les NodePorts)"
if $KC get nodes >/dev/null 2>&1; then
  $KC delete ns argocd dev test prod --ignore-not-found --wait=false >/dev/null 2>&1 \
    && echo "  namespaces argocd/dev/test/prod supprimés (NodePorts libérés)" \
    || echo "  (namespaces déjà absents)"
else
  echo "  (cluster Kubernetes indisponible — rien à supprimer)"
fi

log "Terminé — environnement démonté, ports libérés"
echo "Tu peux relancer :  bash scripts/secret/bootstrap.sh"
echo "Pour libérer TOUTE la RAM : arrête Docker Desktop"
echo "(son démarrage automatique est désactivé — il ne reviendra pas au boot)."
