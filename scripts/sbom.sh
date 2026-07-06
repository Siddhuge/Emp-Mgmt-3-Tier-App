#!/usr/bin/env bash
# Generate an SBOM per image in both SPDX and CycloneDX JSON (via Syft).
# Output: sbom/<component>.spdx.json and sbom/<component>.cdx.json
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require syft

SBOM_DIR="${ROOT_DIR}/sbom"
mkdir -p "${SBOM_DIR}"

for component in "${COMPONENTS[@]}"; do
  ref="$(image_ref "${component}" "${VERSION}")"
  log "SBOM for ${ref}"
  syft scan "${ref}" \
    -o "spdx-json=${SBOM_DIR}/${component}.spdx.json" \
    -o "cyclonedx-json=${SBOM_DIR}/${component}.cdx.json" \
    -q
  pkgs="$(grep -o '"name"' "${SBOM_DIR}/${component}.spdx.json" | wc -l | tr -d ' ')"
  log "  wrote ${component}.spdx.json / ${component}.cdx.json (~${pkgs} components)"
done

log "SBOMs written to ${SBOM_DIR}/"
