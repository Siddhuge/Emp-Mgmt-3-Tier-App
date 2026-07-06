#!/usr/bin/env bash
# Sign images with cosign (keypair mode) and record the digest.
#
# Cosign attaches signatures to the image *in a registry*, addressed by digest,
# so images must be pushed first. Keys:
#   - key-pair mode (default): uses cosign.key / cosign.pub (COSIGN_PASSWORD)
#   - keyless mode: set COSIGN_EXPERIMENTAL=1 and use --identity (OIDC)
#
#   ./scripts/sign.sh                 # sign pushed images
#   ./scripts/sign.sh --verify        # verify signatures
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require cosign
require docker

KEY="${ROOT_DIR}/cosign.key"
PUB="${ROOT_DIR}/cosign.pub"
export COSIGN_PASSWORD="${COSIGN_PASSWORD:-}"

ensure_keys() {
  if [[ ! -f "${KEY}" ]]; then
    log "Generating cosign key pair (cosign.key / cosign.pub)"
    ( cd "${ROOT_DIR}" && cosign generate-key-pair )
  fi
}

digest_ref() {
  # Resolve component:VERSION to a registry ref pinned by digest.
  local ref; ref="$(image_ref "$1" "${VERSION}")"
  local digest
  digest="$(docker inspect --format '{{index .RepoDigests 0}}' "${ref}" 2>/dev/null || true)"
  [[ -n "${digest}" ]] && echo "${digest}" || echo "${ref}"
}

if [[ "${1:-}" == "--verify" ]]; then
  for component in "${COMPONENTS[@]}"; do
    ref="$(digest_ref "${component}")"
    log "Verifying ${ref}"
    cosign verify --key "${PUB}" "${ref}" >/dev/null && log "  OK: signature valid"
  done
  exit 0
fi

ensure_keys
for component in "${COMPONENTS[@]}"; do
  ref="$(digest_ref "${component}")"
  if [[ "${ref}" != *"@sha256:"* ]]; then
    warn "${component}: no registry digest found — push the image before signing."
    continue
  fi
  log "Signing ${ref}"
  cosign sign --yes --key "${KEY}" "${ref}"
done
log "Signing complete. Public key: ${PUB}"
