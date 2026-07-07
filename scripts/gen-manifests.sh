#!/usr/bin/env bash
# Regenerate the plain manifests (k8s/manifests) and the Kustomize base
# (k8s/kustomize/base) from the Helm chart — the single source of truth.
# Dynamic values are emitted as ${REGISTRY} / ${KV_*} placeholders (envsubst).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

CHART=helm/employee-management
OUT=k8s/manifests
BASE=k8s/kustomize/base
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Rendering chart -> plain manifests"
helm template employee-management "$CHART" \
  --namespace employee-management \
  --set keyVault.enabled=true \
  --set 'keyVault.name=${KV_NAME}' \
  --set 'keyVault.tenantId=${KV_TENANT_ID}' \
  --set 'keyVault.clientId=${KV_CLIENT_ID}' \
  --set 'image.registry=${REGISTRY}' \
  --output-dir "$TMP" >/dev/null

# Refresh plain manifests (strip Helm-only labels/comments).
find "$OUT" -maxdepth 1 -name '*.yaml' ! -name '00-namespace.yaml' -delete
cp "$TMP"/employee-management/templates/*.yaml "$OUT"/
sed -i '/helm.sh\/chart:/d; /app.kubernetes.io\/managed-by: Helm/d; /^# Source:/d' "$OUT"/*.yaml

# Mirror into the Kustomize base (everything except the Namespace).
find "$BASE" -maxdepth 1 -name '*.yaml' ! -name 'kustomization.yaml' -delete
for f in "$OUT"/*.yaml; do
  b="$(basename "$f")"
  [ "$b" = "00-namespace.yaml" ] && continue
  cp "$f" "$BASE/$b"
done

echo "Done. Plain manifests: $OUT/  |  Kustomize base: $BASE/"
echo "Validate: kubectl kustomize k8s/kustomize/overlays/dev"
