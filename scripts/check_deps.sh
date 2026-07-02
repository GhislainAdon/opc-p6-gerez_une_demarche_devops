#!/usr/bin/env bash
# check_deps.sh — dependency management & audit helper.
#
# Purpose  : list and audit the dependencies of a component before build,
#            so vulnerable or outdated packages are surfaced early in CI.
# Usage    : scripts/check_deps.sh <front|back>
# Output   : reports/deps-<component>.txt (kept as CI artifact)
# Exit code: always 0 (observation job) — the security gate is enforced
#            later by Trivy/SonarQube, not by this report.
set -euo pipefail

COMPONENT="${1:?usage: check_deps.sh <front|back>}"
REPORT_DIR="reports"
REPORT="${REPORT_DIR}/deps-${COMPONENT}.txt"
mkdir -p "${REPORT_DIR}"

echo "== Dependency report for '${COMPONENT}' — $(date -u +%Y-%m-%dT%H:%M:%SZ) ==" | tee "${REPORT}"

case "${COMPONENT}" in
  front)
    cd front
    echo "-- npm audit (high and above) --" | tee -a "../${REPORT}"
    npm audit --audit-level=high 2>&1 | tee -a "../${REPORT}" || true
    echo "-- outdated packages --" | tee -a "../${REPORT}"
    npm outdated 2>&1 | tee -a "../${REPORT}" || true
    ;;
  back)
    cd back
    echo "-- gradle dependency tree (runtimeClasspath) --" | tee -a "../${REPORT}"
    ./gradlew --no-daemon -q dependencies --configuration runtimeClasspath 2>&1 | tee -a "../${REPORT}" || true
    ;;
  *)
    echo "unknown component: ${COMPONENT}" >&2
    exit 1
    ;;
esac

echo "Report written to ${REPORT}"
