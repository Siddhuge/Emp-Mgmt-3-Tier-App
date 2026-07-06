#!/usr/bin/env bash
# Push every component's version + git tags to the configured registry.
#   REGISTRY=docker.io/you VERSION=1.0.0 ./scripts/push.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require docker

if [[ "${REGISTRY}" != *"/"* && "${REGISTRY}" != *"."* && "${REGISTRY}" != *":"* ]]; then
  warn "REGISTRY='${REGISTRY}' looks local (no host). Set REGISTRY to a real"
  warn "registry (docker.io/you, *.azurecr.io, *.dkr.ecr.*, localhost:5000)."
fi

for component in "${COMPONENTS[@]}"; do
  for tag in "${VERSION}" "git-${VCS_REF}"; do
    ref="$(image_ref "${component}" "${tag}")"
    log "Pushing ${ref}"
    docker push "${ref}"
  done
done
log "Push complete."
