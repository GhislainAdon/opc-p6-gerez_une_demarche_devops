#!/usr/bin/env bash
# backup.sh — build artifacts back-up.
#
# Purpose  : archive the deployable artifacts (backend JAR, frontend bundle)
#            in a timestamped tarball so any pipeline run can be restored
#            or compared later (rollback support).
# Usage    : scripts/backup.sh [output-dir]   (default: backups/)
# Inputs   : back/build/libs/*.jar, front/dist/  (must exist — run builds first)
# Output   : <output-dir>/backup-<UTC timestamp>-<git SHA>.tar.gz + .sha256
set -euo pipefail

OUT_DIR="${1:-backups}"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
SHA="${CI_COMMIT_SHORT_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo local)}"
ARCHIVE="${OUT_DIR}/backup-${STAMP}-${SHA}.tar.gz"

mkdir -p "${OUT_DIR}"

INCLUDE=()
[ -d back/build/libs ] && INCLUDE+=(back/build/libs)
[ -d front/dist ] && INCLUDE+=(front/dist)

if [ "${#INCLUDE[@]}" -eq 0 ]; then
  echo "ERROR: nothing to back up (run the builds first)" >&2
  exit 1
fi

tar -czf "${ARCHIVE}" "${INCLUDE[@]}"
sha256sum "${ARCHIVE}" > "${ARCHIVE}.sha256"

echo "Backup written: ${ARCHIVE} ($(du -h "${ARCHIVE}" | cut -f1))"
echo "Checksum      : $(cat "${ARCHIVE}.sha256")"
