#!/usr/bin/env bash
# gitops_release.sh — GitOps release step.
#
# Pins the freshly built image (registry + tag) into the environment's Helm
# values file and pushes the change back to the environment branch. Argo CD,
# running on the local cluster, polls that branch and deploys the new version.
# The pipeline therefore never needs inbound access to the cluster.
#
# Usage : gitops_release.sh <env> <registry> <tag>
#   env      -> dev | test | prod  (also the git branch and values-<env>.yaml suffix)
#   registry -> $CI_REGISTRY_IMAGE  (front/back live under <registry>/{front,back})
#   tag      -> image tag, e.g. dev-abc1234
#
# Requires (in CI): yq (v4), git, and $GITOPS_PUSH_TOKEN with write_repository.
set -euo pipefail

ENV="${1:?usage: gitops_release.sh <env> <registry> <tag>}"
REGISTRY="${2:?registry required}"
TAG="${3:?tag required}"
VALUES="deploy/helm/microcrm/values-${ENV}.yaml"

[ -f "$VALUES" ] || { echo "No Helm values file for env '$ENV' ($VALUES)"; exit 1; }

# Pin the image the cluster must run.
yq -i ".image.registry = \"$REGISTRY\" | .image.tag = \"$TAG\"" "$VALUES"

if git diff --quiet -- "$VALUES"; then
  echo "Image already pinned to '$TAG' for '$ENV' — nothing to release."
  exit 0
fi

git config user.email "ci@orion.local"
git config user.name  "Orion CI (GitOps)"
git add "$VALUES"
git commit -m "chore(release): deploy $TAG to $ENV [skip ci]"

# Push back to the environment branch. [skip ci] + ci.skip avoid a pipeline loop.
git push -o ci.skip \
  "https://oauth2:${GITOPS_PUSH_TOKEN}@${CI_SERVER_HOST}/${CI_PROJECT_PATH}.git" \
  "HEAD:${ENV}"

echo "Released '$TAG' to '$ENV' — Argo CD will sync it into namespace '$ENV'."
