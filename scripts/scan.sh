#!/usr/bin/env bash
# Scan images for OS/library vulnerabilities and embedded secrets with Trivy.
# Writes JSON + table reports to reports/ and fails on the configured severity.
#
#   FAIL_ON=CRITICAL ./scripts/scan.sh        # default
#   FAIL_ON=HIGH,CRITICAL ./scripts/scan.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require trivy

FAIL_ON="${FAIL_ON:-CRITICAL}"
REPORT_DIR="${ROOT_DIR}/reports"
mkdir -p "${REPORT_DIR}"

rc=0
for component in "${COMPONENTS[@]}"; do
  ref="$(image_ref "${component}" "${VERSION}")"
  log "Scanning ${ref} (vulns + secrets), fail-on=${FAIL_ON}"

  # Full JSON report (all severities) for the record.
  trivy image --quiet --scanners vuln,secret \
    --format json --output "${REPORT_DIR}/${component}-trivy.json" "${ref}" || true

  # Human-readable table.
  trivy image --quiet --scanners vuln,secret \
    --format table "${ref}" | tee "${REPORT_DIR}/${component}-trivy.txt" || true

  # Gate: non-zero exit if anything at/above FAIL_ON severity is found.
  # Honors ../.trivyignore for reviewed/accepted CVEs.
  if ! trivy image --quiet --scanners vuln,secret \
        --severity "${FAIL_ON}" --exit-code 1 --ignore-unfixed \
        --ignorefile "${ROOT_DIR}/.trivyignore" "${ref}" >/dev/null 2>&1; then
    err "${component}: findings at severity ${FAIL_ON} (fixable)"
    rc=1
  else
    log "${component}: no fixable ${FAIL_ON} findings"
  fi
done

[[ ${rc} -eq 0 ]] && log "Scan gate passed." || err "Scan gate failed."
exit ${rc}
