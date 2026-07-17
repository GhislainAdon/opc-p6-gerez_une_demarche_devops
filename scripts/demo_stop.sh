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
KC_R="$KC --request-timeout=15s"
if $KC_R get nodes >/dev/null 2>&1; then
  # 1) Lever les finalizers des Applications AVANT de supprimer les namespaces —
  #    sinon le finalizer resources-finalizer.argocd.argoproj.io bloque le
  #    namespace en « Terminating » pour toujours (le contrôleur disparaît avec lui).
  for app in microcrm-dev microcrm-test microcrm-prod; do
    $KC_R -n argocd patch application "$app" --type merge \
      -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1 || true
  done
  # 2) Supprimer, puis attendre la fin RÉELLE (le prochain bootstrap doit pouvoir
  #    recréer les namespaces sans conflit).
  $KC_R delete ns argocd dev test prod --ignore-not-found --wait=false >/dev/null 2>&1 || true
  printf '  suppression en cours'
  for _ in $(seq 1 36); do
    left=$($KC_R get ns argocd dev test prod --no-headers 2>/dev/null | wc -l)
    [ "${left:-0}" = "0" ] && break; printf '.'; sleep 5
  done
  echo " terminé — namespaces argocd/dev/test/prod supprimés (NodePorts libérés)"
else
  echo "  (cluster Kubernetes indisponible — rien à supprimer)"
fi

log "Terminé — environnement démonté, ports libérés"
echo "Tu peux relancer :  bash scripts/secret/bootstrap.sh"
echo "Pour libérer TOUTE la RAM : arrête Docker Desktop"
echo "(son démarrage automatique est désactivé — il ne reviendra pas au boot)."
