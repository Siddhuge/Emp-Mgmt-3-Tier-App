#!/usr/bin/env bash
# Create a local 3-node kind cluster for Phase 3 and install its dependencies:
#   - NGINX Ingress controller (kind flavor)
#   - metrics-server (patched for kind) so the HPA can read metrics
#   - loads the Phase 2 images into the cluster
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require kind
require kubectl

CLUSTER="${KIND_CLUSTER:-ems}"

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER}"; then
  log "kind cluster '${CLUSTER}' already exists"
else
  log "Creating kind cluster '${CLUSTER}' (1 control-plane + 2 workers)"
  kind create cluster --config "${ROOT_DIR}/helm/kind-cluster.yaml" --wait 120s
fi

log "Loading images into the cluster"
for c in backend frontend database-init; do
  kind load docker-image --name "${CLUSTER}" "$(image_ref "$c" "${VERSION}")"
done

log "Installing NGINX Ingress controller"
kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml

log "Installing metrics-server (with --kubelet-insecure-tls for kind)"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' || true

log "Waiting for the Ingress controller to be ready"
kubectl -n ingress-nginx wait --for=condition=ready pod \
  -l app.kubernetes.io/component=controller --timeout=180s
# Wait for the admission webhook endpoints to accept connections.
for _ in $(seq 1 40); do
  [[ -n "$(kubectl -n ingress-nginx get endpoints ingress-nginx-controller-admission \
    -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)" ]] && break
  sleep 3
done
kubectl -n kube-system rollout status deploy/metrics-server --timeout=120s || true

log "Cluster '${CLUSTER}' is ready. Deploy with: make k8s-deploy"
