#!/usr/bin/env bash
# End-to-end DevSecOps pipeline:
#   build -> scan -> SBOM -> [push -> sign -> verify]
#
# Local (no registry):   ./scripts/release.sh
# Full release:          REGISTRY=docker.io/you PUSH=1 ./scripts/release.sh
set -euo pipefail
HERE="$(dirname "${BASH_SOURCE[0]}")"
source "${HERE}/lib.sh"

PUSH="${PUSH:-0}"

log "=== 1/5 Build ==="        ; "${HERE}/build.sh"
log "=== 2/5 Vulnerability scan ===" ; "${HERE}/scan.sh"
log "=== 3/5 SBOM ==="         ; "${HERE}/sbom.sh"

if [[ "${PUSH}" == "1" ]]; then
  log "=== 4/5 Push ==="       ; "${HERE}/push.sh"
  log "=== 5/5 Sign & verify ===" ; "${HERE}/sign.sh" && "${HERE}/sign.sh" --verify
else
  warn "PUSH=0 -> skipping push & sign (set REGISTRY + PUSH=1 to publish)."
fi

log "Release pipeline finished for version ${VERSION} (ref ${VCS_REF})."
