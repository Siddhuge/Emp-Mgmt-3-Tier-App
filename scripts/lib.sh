#!/usr/bin/env bash
# Shared helpers for the Phase 2 build/scan/sbom/sign scripts.
set -euo pipefail

# Resolve repo root (this file lives in <root>/scripts).
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---- Configuration (override via environment) ----
REGISTRY="${REGISTRY:-employee-management}"

# Semantic version comes from the VERSION file unless overridden.
if [[ -z "${VERSION:-}" ]]; then
  VERSION="$(tr -d '[:space:]' < "${ROOT_DIR}/VERSION" 2>/dev/null || echo dev)"
fi

# Immutable VCS reference. Uses git when available, else a timestamp — never
# a moving tag like "latest".
if [[ -z "${VCS_REF:-}" ]]; then
  if git -C "${ROOT_DIR}" rev-parse --short HEAD >/dev/null 2>&1; then
    VCS_REF="$(git -C "${ROOT_DIR}" rev-parse --short HEAD)"
  else
    VCS_REF="$(date -u +%Y%m%d%H%M%S)"
  fi
fi

BUILD_DATE="${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

# The three application images (component -> build context).
COMPONENTS=(backend frontend database-init)

# Map a component name to its build context directory.
context_for() {
  case "$1" in
    backend)       echo "${ROOT_DIR}/backend" ;;
    frontend)      echo "${ROOT_DIR}/frontend" ;;
    database-init) echo "${ROOT_DIR}/database" ;;
    *) echo "unknown component: $1" >&2; return 1 ;;
  esac
}

# Fully-qualified image reference for a component + tag.
image_ref() { echo "${REGISTRY}/$1:$2"; }

# Colored logging.
log()  { printf '\033[1;34m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; }

require() {
  command -v "$1" >/dev/null 2>&1 || { err "'$1' is required but not installed."; exit 1; }
}
