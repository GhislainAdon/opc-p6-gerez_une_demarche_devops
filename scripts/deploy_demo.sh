#!/usr/bin/env bash
# deploy_demo.sh — automated deployment of the built images + smoke test.
#
# Purpose  : deploy the freshly built front/back images on a Docker host
#            (demo environment or CI docker:dind service) and verify that
#            both services answer — replaces the manual `docker run` steps
#            previously performed by the Ops team.
# Usage    : scripts/deploy_demo.sh <back-image> <front-image>
# Requires : docker CLI + a reachable Docker daemon; images pullable
#            (CI registry login must be done by the caller).
# Exit code: 0 if both services answer, non-zero otherwise.
set -euo pipefail

BACK_IMAGE="${1:?usage: deploy_demo.sh <back-image> <front-image>}"
FRONT_IMAGE="${2:?usage: deploy_demo.sh <back-image> <front-image>}"
# In GitLab CI with docker:dind, published ports live on the `docker` service
# host — set DEPLOY_HOST=docker in the job. Defaults to localhost for a
# workstation or demo server run.
DEPLOY_HOST="${DEPLOY_HOST:-localhost}"
NETWORK="orion-demo"
RETRIES=30

cleanup() {
  docker rm -f orion-back orion-front >/dev/null 2>&1 || true
  docker network rm "${NETWORK}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cleanup
docker network create "${NETWORK}" >/dev/null

echo ">> starting backend  (${BACK_IMAGE})"
docker run -d --name orion-back --network "${NETWORK}" -p 8081:8080 "${BACK_IMAGE}" >/dev/null
echo ">> starting frontend (${FRONT_IMAGE})"
docker run -d --name orion-front --network "${NETWORK}" -p 8082:8080 "${FRONT_IMAGE}" >/dev/null

wait_http() {
  local name="$1" url="$2" i=0
  until curl -fsS -o /dev/null "${url}"; do
    i=$((i + 1))
    if [ "${i}" -ge "${RETRIES}" ]; then
      echo "ERROR: ${name} did not answer at ${url} after ${RETRIES} attempts" >&2
      docker logs "${name}" | tail -20 >&2 || true
      return 1
    fi
    sleep 2
  done
  echo "OK: ${name} answers at ${url}"
}

wait_http orion-back "http://${DEPLOY_HOST}:8081/"
wait_http orion-front "http://${DEPLOY_HOST}:8082/"

echo ">> smoke deployment successful — services up and answering."
