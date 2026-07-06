#!/usr/bin/env bash
# Demonstrate the scan -> SBOM -> sign -> verify supply-chain flow fully locally
# by standing up an ephemeral registry (registry:2) on localhost:5000.
# Nothing leaves the machine; the registry is removed at the end.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require docker
require cosign

REG_PORT="${REG_PORT:-5000}"
LOCAL_REGISTRY="localhost:${REG_PORT}"
REG_NAME="ems_local_registry"

cleanup() {
  log "Removing local registry"
  docker rm -f "${REG_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

log "Starting ephemeral registry at ${LOCAL_REGISTRY}"
docker rm -f "${REG_NAME}" >/dev/null 2>&1 || true
docker run -d --name "${REG_NAME}" -p "${REG_PORT}:5000" registry:2 >/dev/null
sleep 2

KEY="${ROOT_DIR}/cosign.key"; PUB="${ROOT_DIR}/cosign.pub"
export COSIGN_PASSWORD="${COSIGN_PASSWORD:-}"
if [[ ! -f "${KEY}" ]]; then
  log "Generating cosign key pair"
  ( cd "${ROOT_DIR}" && cosign generate-key-pair )
fi

for component in "${COMPONENTS[@]}"; do
  src="$(image_ref "${component}" "${VERSION}")"
  dst="${LOCAL_REGISTRY}/$(basename "${REGISTRY}")/${component}:${VERSION}"

  log "Push ${component} -> ${dst}"
  docker tag "${src}" "${dst}"
  docker push "${dst}" >/dev/null

  digest="$(docker inspect --format '{{index .RepoDigests 0}}' "${dst}")"
  log "Sign ${digest}"
  cosign sign --yes --key "${KEY}" "${digest}" >/dev/null 2>&1

  log "Verify ${component}"
  cosign verify --key "${PUB}" "${digest}" >/dev/null 2>&1 \
    && log "  ✔ signature verified" \
    || { err "  signature verification failed"; exit 1; }
done

log "Local sign/verify demo complete — all images signed and verified."
