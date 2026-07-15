#!/usr/bin/env bash
# bootstrap.example.sh — local demo bootstrap (TEMPLATE, safe to commit).
#
# Copy this file to  scripts/secret/bootstrap.sh  (gitignored) and fill in
# scripts/secret/.env.secret. That real script holds your GitLab admin token
# and the Discord webhooks — it MUST NOT be committed.
#
# What it does, end to end, on your machine (Docker Desktop + Kubernetes on):
#   1. starts SonarQube in Docker and waits for it to be UP
#   2. opens a Cloudflare quick tunnel exposing SonarQube publicly
#   3. generates a SonarQube CI token
#   4. installs Argo CD in the Docker Desktop cluster, creates the dev/test/prod
#      namespaces + the private-registry pull secret, registers the repo and
#      applies the dev Application
#   5. sets every GitLab CI/CD variable the pipeline needs, via the GitLab API
#   6. prints the 3 links you asked for (SonarQube, Argo CD, Sonar token page)
#
# Re-runnable: variables are updated in place, containers are reused.
set -euo pipefail
cd "$(dirname "$0")/../.."   # repo root

# ---- secrets (gitignored) -------------------------------------------------
# scripts/secret/.env.secret must define:
#   GITLAB_TOKEN=glpat-...            # api scope (admin on the project)
#   GITLAB_PROJECT=openclassrooms7804126/opc-p6-gerez_une_demarche_devops
#   GITOPS_PUSH_TOKEN=glpat-...       # write_repository (can equal GITLAB_TOKEN)
#   REGISTRY_USER=...                 # deploy-token user (read_registry)
#   REGISTRY_TOKEN=...                # deploy-token secret
#   DISCORD_WEBHOOK_URL_DEV=https://discord.com/api/webhooks/...
#   DISCORD_WEBHOOK_URL_TEST=https://discord.com/api/webhooks/...
#   DISCORD_WEBHOOK_URL_PROD=https://discord.com/api/webhooks/...
# optional:
#   SONAR_PORT=9000  SONAR_ADMIN_PASS=Orion-demo-2026
ENV_FILE="scripts/secret/.env.secret"
[ -f "$ENV_FILE" ] || { echo "Missing $ENV_FILE (copy .env.secret.example and fill it)"; exit 1; }
set -a; . "$ENV_FILE"; set +a

: "${GITLAB_TOKEN:?}" "${GITLAB_PROJECT:?}" "${GITOPS_PUSH_TOKEN:?}"
: "${DISCORD_WEBHOOK_URL_DEV:?}" "${DISCORD_WEBHOOK_URL_TEST:?}" "${DISCORD_WEBHOOK_URL_PROD:?}"
SONAR_PORT="${SONAR_PORT:-9000}"
SONAR_ADMIN_PASS="${SONAR_ADMIN_PASS:-Orion-demo-2026}"
API="https://gitlab.com/api/v4"
PROJECT_ENC=$(printf '%s' "$GITLAB_PROJECT" | sed 's|/|%2F|g')

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

# ---- 0. Remise à zéro de la branche dev (démo propre) ---------------------
# Réinitialise "dev" sur "master" (état baseline, exercice non traité) via
# l'API GitLab : la démo repart d'un dev vierge, puis on merge solution -> dev
# en direct pour montrer la pipeline. test/prod sont des branches PROTÉGÉES
# (figuration de la promotion dev -> test -> prod) et ne sont pas touchées.
# Mets RESET_DEMO=0 pour conserver l'état courant de dev.
if [ "${RESET_DEMO:-1}" = "1" ]; then
  log "Réinitialisation de la branche dev sur master (démo propre)"
  # supprime dev si elle existe (branche non protégée)…
  curl -s -o /dev/null -X DELETE \
    "$API/projects/$PROJECT_ENC/repository/branches/dev" \
    --header "PRIVATE-TOKEN: $GITLAB_TOKEN" || true
  # …puis la recrée à partir de master.
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "$API/projects/$PROJECT_ENC/repository/branches?branch=dev&ref=master" \
    --header "PRIVATE-TOKEN: $GITLAB_TOKEN")
  echo "  dev -> baseline master  [HTTP $code]"
  # Cluster propre : retire l'app Argo CD dev (recréée plus bas). Elle se
  # (re)déploiera pour de vrai au premier merge solution -> dev pendant la démo.
  kubectl delete -f deploy/argocd/application-dev.yaml --ignore-not-found >/dev/null 2>&1 || true
  kubectl -n dev delete deploy,svc --all >/dev/null 2>&1 || true
fi

# ---- 1. SonarQube ---------------------------------------------------------
log "Starting SonarQube on :$SONAR_PORT"
if ! docker ps -a --format '{{.Names}}' | grep -qx sonarqube; then
  docker run -d --name sonarqube -p "${SONAR_PORT}:9000" \
    -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true sonarqube:community
else
  docker start sonarqube >/dev/null
fi
echo -n "Waiting for SonarQube"
until curl -sf "http://localhost:${SONAR_PORT}/api/system/status" | grep -q '"status":"UP"'; do
  echo -n "."; sleep 5
done; echo " UP"

# ---- 2. Cloudflare quick tunnel ------------------------------------------
log "Opening Cloudflare quick tunnel to SonarQube"
TUN_LOG="scripts/secret/cloudflared-sonar.log"; : > "$TUN_LOG"
cloudflared tunnel --url "http://localhost:${SONAR_PORT}" --no-autoupdate > "$TUN_LOG" 2>&1 &
CF_PID=$!; echo "$CF_PID" > scripts/secret/cloudflared.pid
echo -n "Waiting for public URL"
SONAR_PUBLIC=""
for _ in $(seq 1 30); do
  SONAR_PUBLIC=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$TUN_LOG" | head -1 || true)
  [ -n "$SONAR_PUBLIC" ] && break; echo -n "."; sleep 2
done; echo
[ -n "$SONAR_PUBLIC" ] || { echo "Could not read the tunnel URL from $TUN_LOG"; exit 1; }
echo "SonarQube public URL: $SONAR_PUBLIC"

# ---- 3. SonarQube CI token -----------------------------------------------
log "Generating SonarQube CI token"
# Change the default admin password (idempotent: ignore failure if already set).
curl -su "admin:admin" -X POST \
  "http://localhost:${SONAR_PORT}/api/user_tokens/revoke" --data "name=orion-ci" >/dev/null 2>&1 || true
curl -su "admin:admin" -X POST "http://localhost:${SONAR_PORT}/api/users/change_password" \
  --data "login=admin&previousPassword=admin&password=${SONAR_ADMIN_PASS}" >/dev/null 2>&1 || true
# Génère le token — avec retry : sur une instance fraîche, la génération peut
# renvoyer vide tant que SonarQube n'est pas complètement prêt (sinon SONAR_TOKEN
# resterait périmé et l'analyse échouerait en 401).
SONAR_TOKEN=""
for _ in $(seq 1 10); do
  curl -su "admin:${SONAR_ADMIN_PASS}" -X POST \
    "http://localhost:${SONAR_PORT}/api/user_tokens/revoke" --data "name=orion-ci" >/dev/null 2>&1 || true
  SONAR_TOKEN=$(curl -su "admin:${SONAR_ADMIN_PASS}" -X POST \
    "http://localhost:${SONAR_PORT}/api/user_tokens/generate?name=orion-ci" \
    | grep -oE '"token":"[^"]+"' | cut -d'"' -f4 || true)
  [ -n "$SONAR_TOKEN" ] && break; sleep 3
done
[ -n "$SONAR_TOKEN" ] || echo "WARN: token not auto-generated — create one at ${SONAR_PUBLIC}/account/security"

# ---- 3b. Quality gate « Orion » (réaliste, phase d'observation) -----------
# Clean-as-you-code SANS seuil de couverture bloquant tant que la couverture
# monte (cf. plan de tests : 2 semaines d'observation, seuils relevés par
# paliers). La gate bloque toujours sur : nouvelle violation, hotspot non revu,
# duplication du code neuf > 3 % — donc la démo DEMO-GATE (secret en dur) la
# fait passer au rouge, mais une promotion propre reste verte à coup sûr.
log "Configuring SonarQube quality gate 'Orion'"
SQ="http://localhost:${SONAR_PORT}"; SQAUTH="admin:${SONAR_ADMIN_PASS}"
# Créer la gate — elle hérite des conditions 'Sonar way' par défaut
# (new_violations=0, new_coverage>=80, duplication<=3, hotspots revus=100 %).
curl -su "$SQAUTH" -X POST "$SQ/api/qualitygates/create" --data "name=Orion" >/dev/null 2>&1 || true
# Retirer UNIQUEMENT la condition de couverture (phase d'observation, seuils
# relevés par paliers) ; on garde les 3 autres conditions bloquantes.
COV_ID=$(curl -su "$SQAUTH" "$SQ/api/qualitygates/show?name=Orion" \
  | python3 -c "import sys,json;print(next((c['id'] for c in json.load(sys.stdin).get('conditions',[]) if c['metric']=='new_coverage'),''))" 2>/dev/null)
[ -n "$COV_ID" ] && curl -su "$SQAUTH" -X POST "$SQ/api/qualitygates/delete_condition" --data "id=$COV_ID" >/dev/null 2>&1 || true
# Définir par défaut (pour un projet neuf) + associer explicitement au projet.
curl -su "$SQAUTH" -X POST "$SQ/api/qualitygates/set_as_default" --data "name=Orion" >/dev/null 2>&1 || true
curl -su "$SQAUTH" -X POST "$SQ/api/qualitygates/select" \
  --data "gateName=Orion&projectKey=orion-fullstack" >/dev/null 2>&1 || true
echo "  gate 'Orion' : new_violations=0, hotspots revus=100 %, duplication<=3 % (couverture non bloquante)"

# ---- 4. Argo CD + cluster ------------------------------------------------
log "Configuring Kubernetes (Docker Desktop) + Argo CD"
kubectl config use-context docker-desktop
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
# --server-side évite la limite d'annotation (le CRD applicationsets dépasse
# 262144 octets en apply client-side).
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
for ns in dev test prod; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
  if [ -n "${REGISTRY_USER:-}" ] && [ -n "${REGISTRY_TOKEN:-}" ]; then
    kubectl -n "$ns" create secret docker-registry gitlab-registry \
      --docker-server=registry.gitlab.com \
      --docker-username="$REGISTRY_USER" --docker-password="$REGISTRY_TOKEN" \
      --dry-run=client -o yaml | kubectl apply -f -
  fi
done
kubectl -n argocd rollout status deploy/argocd-server --timeout=180s
# Register the (private) repo so Argo CD can read it, then apply the dev app.
kubectl -n argocd create secret generic repo-opc-p6 \
  --from-literal=type=git \
  --from-literal=url="https://gitlab.com/${GITLAB_PROJECT}.git" \
  --from-literal=username=oauth2 \
  --from-literal=password="$GITLAB_TOKEN" \
  --dry-run=client -o yaml \
  | kubectl -n argocd label --local -f - argocd.argoproj.io/secret-type=repository -o yaml \
  | kubectl apply -f -
kubectl apply -f deploy/argocd/application-dev.yaml
ARGO_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d 2>/dev/null || echo "<see argocd-initial-admin-secret>")

# ---- 5. GitLab CI/CD variables -------------------------------------------
log "Setting GitLab CI/CD variables via the API"
set_var() { # key value masked
  local key="$1" val="$2" masked="${3:-true}"
  curl -sf -X PUT "$API/projects/$PROJECT_ENC/variables/$key" \
    --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    --form "value=$val" --form "masked=$masked" --form "protected=false" >/dev/null 2>&1 \
  || curl -sf -X POST "$API/projects/$PROJECT_ENC/variables" \
    --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    --form "key=$key" --form "value=$val" --form "masked=$masked" --form "protected=false" >/dev/null
  echo "  set $key"
}
set_var SONAR_HOST_URL "$SONAR_PUBLIC" false
[ -n "$SONAR_TOKEN" ] && set_var SONAR_TOKEN "$SONAR_TOKEN" true
set_var GITOPS_PUSH_TOKEN "$GITOPS_PUSH_TOKEN" true
set_var DISCORD_WEBHOOK_URL_DEV  "$DISCORD_WEBHOOK_URL_DEV"  true
set_var DISCORD_WEBHOOK_URL_TEST "$DISCORD_WEBHOOK_URL_TEST" true
set_var DISCORD_WEBHOOK_URL_PROD "$DISCORD_WEBHOOK_URL_PROD" true

# ---- 6. The three links --------------------------------------------------
log "Done — your demo links"
cat <<EOF

  SonarQube (public) : $SONAR_PUBLIC
  SonarQube token    : ${SONAR_PUBLIC}/account/security   (admin / ${SONAR_ADMIN_PASS})
  Argo CD UI         : run  kubectl -n argocd port-forward svc/argocd-server 8080:443
                       then https://localhost:8080   (admin / ${ARGO_PASS})

  GitLab variables set: SONAR_HOST_URL, SONAR_TOKEN, GITOPS_PUSH_TOKEN,
                        DISCORD_WEBHOOK_URL_DEV/_TEST/_PROD
  Tunnel PID: $(cat scripts/secret/cloudflared.pid)  (kill it to close the tunnel)

  Next: merge solution -> dev and watch the pipeline deploy to namespace 'dev'.
EOF
