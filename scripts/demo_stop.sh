#!/usr/bin/env bash
# demo_stop.sh — arrête proprement les services locaux de la démo pour libérer
# la RAM : SonarQube (Docker), le tunnel Cloudflare, et Argo CD (scale à 0, sans
# désinstaller). Contient zéro secret → versionnable sans risque.
#
# Usage : bash scripts/demo_stop.sh
# Pour tout couper (y compris le cluster) : arrêter ensuite Docker Desktop.
set -u

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

# --- SonarQube ---
log "Arrêt de SonarQube"
docker stop orion-sonarqube 2>/dev/null && echo "  SonarQube arrêté" || echo "  (conteneur orion-sonarqube absent)"

# --- Tunnel Cloudflare ---
log "Fermeture du tunnel cloudflared"
if command -v taskkill >/dev/null 2>&1; then
  taskkill //IM cloudflared.exe //F >/dev/null 2>&1 && echo "  tunnel fermé" || echo "  (aucun cloudflared en cours)"
else
  pkill -f "cloudflared tunnel" 2>/dev/null && echo "  tunnel fermé" || echo "  (aucun cloudflared en cours)"
fi
rm -f scripts/secret/cloudflared.pid scripts/secret/cloudflared-sonar.log 2>/dev/null || true

# --- Argo CD (scale à 0 : libère la RAM sans désinstaller) ---
log "Mise en veille d'Argo CD (scale 0)"
if kubectl --context docker-desktop get ns argocd >/dev/null 2>&1; then
  kubectl --context docker-desktop -n argocd scale deploy --all --replicas=0 >/dev/null 2>&1 || true
  kubectl --context docker-desktop -n argocd scale statefulset --all --replicas=0 >/dev/null 2>&1 || true
  echo "  Argo CD en veille (relance : kubectl -n argocd scale deploy,statefulset --all --replicas=1)"
else
  echo "  (namespace argocd absent)"
fi

log "Terminé"
echo "Pour libérer TOUTE la RAM du cluster : arrête Docker Desktop"
echo "(son démarrage automatique est déjà désactivé — il ne reviendra pas au boot)."
