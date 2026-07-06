#!/usr/bin/env bash
# Local production validation — brings up docker-compose.prod.yml and checks the
# Phase 2 acceptance criteria, then tears the stack down.
#
#   ./scripts/validate.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require docker
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env.dev}"
COMPOSE=(docker compose --env-file "${ENV_FILE}" -f "${ROOT_DIR}/docker-compose.prod.yml")

pass=0; fail=0
check() { # check "desc" <cmd...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then printf '  \033[1;32m✔\033[0m %s\n' "${desc}"; pass=$((pass+1));
  else printf '  \033[1;31mx\033[0m %s\n' "${desc}"; fail=$((fail+1)); fi
}

cleanup() { log "Tearing down"; "${COMPOSE[@]}" down -v >/dev/null 2>&1 || true; }
trap cleanup EXIT

export VERSION VCS_REF BUILD_DATE REGISTRY
log "Bringing up production stack (env=${ENV_FILE}, version=${VERSION})"
"${COMPOSE[@]}" up -d

log "Waiting for services to become healthy..."
for _ in $(seq 1 40); do
  fe="$(curl -fsS "http://localhost:${FRONTEND_PORT:-8080}/healthz" 2>/dev/null || true)"
  be="$(curl -fsS "http://localhost:${BACKEND_PORT:-8000}/health" 2>/dev/null || true)"
  [[ "${fe}" == "ok" && "${be}" == '{"status":"ok"}' ]] && break
  sleep 3
done

echo
log "Validation checklist:"
check "Frontend loads (GET /)"            curl -fsS "http://localhost:${FRONTEND_PORT:-8080}/"
check "Frontend health (GET /healthz)"    bash -c '[[ "$(curl -fsS http://localhost:'"${FRONTEND_PORT:-8080}"'/healthz)" == "ok" ]]'
check "Backend health (GET /health)"      curl -fsS "http://localhost:${BACKEND_PORT:-8000}/health"
check "Backend API reachable (login)"     bash -c 'curl -fsS -X POST http://localhost:'"${BACKEND_PORT:-8000}"'/api/login -H "Content-Type: application/json" -d "{\"username\":\"admin\",\"password\":\"admin123\"}" | grep -q access_token'
check "DB reachable + seeded"             bash -c 'docker exec ems_db psql -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-employee_db}" -tc "SELECT count(*) FROM employees" | grep -qE "[0-9]"'
check "Backend runs as non-root"          bash -c '[[ "$(docker exec ems_backend id -u)" != "0" ]]'
check "Frontend runs as non-root"         bash -c '[[ "$(docker exec ems_frontend id -u)" != "0" ]]'
check "Backend filesystem is read-only"   bash -c 'docker inspect -f "{{.HostConfig.ReadonlyRootfs}}" ems_backend | grep -q true'
check "Frontend filesystem is read-only"  bash -c 'docker inspect -f "{{.HostConfig.ReadonlyRootfs}}" ems_frontend | grep -q true'
check "no-new-privileges on backend"      bash -c 'docker inspect -f "{{.HostConfig.SecurityOpt}}" ems_backend | grep -q no-new-privileges'
check "All capabilities dropped (backend)" bash -c 'docker inspect -f "{{.HostConfig.CapDrop}}" ems_backend | grep -qi ALL'
check "Config externalized (env, no host source mount)" bash -c '[[ -z "$(docker inspect -f "{{range .Mounts}}{{.Source}} {{end}}" ems_backend | tr -d " ")" || "$(docker inspect -f "{{range .Mounts}}{{.Source}} {{end}}" ems_backend)" != *"/backend/app"* ]]'

echo
log "Image sizes:"
for c in backend frontend database-init; do
  size="$(docker image inspect "$(image_ref "$c" "${VERSION}")" --format '{{.Size}}' 2>/dev/null || echo 0)"
  printf '  %-14s %s\n' "$c" "$(numfmt --to=iec --suffix=B "${size}" 2>/dev/null || echo "${size}B")"
done

echo
log "Result: ${pass} passed, ${fail} failed."
exit "${fail}"
