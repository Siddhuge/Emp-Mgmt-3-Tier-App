#!/usr/bin/env bash
# Build production OCI images for every component with immutable version tags.
#
#   REGISTRY=docker.io/you VERSION=1.0.0 ./scripts/build.sh
#
# Each image is tagged with:  :<VERSION>  and  :git-<VCS_REF>   (never :latest)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require docker

log "Registry : ${REGISTRY}"
log "Version  : ${VERSION}"
log "VCS ref  : ${VCS_REF}"
log "Built at : ${BUILD_DATE}"

for component in "${COMPONENTS[@]}"; do
  ctx="$(context_for "${component}")"
  ver_tag="$(image_ref "${component}" "${VERSION}")"
  ref_tag="$(image_ref "${component}" "git-${VCS_REF}")"

  log "Building ${component} -> ${ver_tag}"
  docker build \
    --build-arg VERSION="${VERSION}" \
    --build-arg VCS_REF="${VCS_REF}" \
    --build-arg BUILD_DATE="${BUILD_DATE}" \
    --tag "${ver_tag}" \
    --tag "${ref_tag}" \
    "${ctx}"
done

log "Built images:"
docker images --format '  {{.Repository}}:{{.Tag}}\t{{.Size}}' | grep "^  ${REGISTRY}/" || true
