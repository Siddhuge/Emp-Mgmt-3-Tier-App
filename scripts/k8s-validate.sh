#!/usr/bin/env bash
# Validate the deployed release against the Phase 3 checklist.
#   NAMESPACE=employee-dev RELEASE=ems ./scripts/k8s-validate.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require kubectl
NS="${NAMESPACE:-employee-dev}"
REL="${RELEASE:-ems}"
HOST="${INGRESS_HOST:-employee.dev.sidhuge.xyz}"
FULL="${REL}-employee-management"

pass=0; fail=0
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then printf '  \033[1;32m✔\033[0m %s\n' "$d"; pass=$((pass+1)); else printf '  \033[1;31mx\033[0m %s\n' "$d"; fail=$((fail+1)); fi; }

log "Port-forwarding the ingress controller..."
kubectl -n ingress-nginx port-forward svc/ingress-nginx-controller 18090:80 >/tmp/ems-pf.log 2>&1 &
PF=$!; trap 'kill ${PF} 2>/dev/null || true' EXIT
sleep 4
BASE="http://localhost:18090"; H="Host: ${HOST}"

TOKEN="$(curl -s -H "$H" -X POST ${BASE}/api/login -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}' | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null || true)"

echo; log "Phase 3 checklist (namespace ${NS}):"
check "Frontend accessible via Ingress"        bash -c "curl -fsS -H '$H' ${BASE}/ | grep -q '<title>'"
check "Frontend health via Ingress"            bash -c "[ \"\$(curl -fsS -H '$H' ${BASE}/healthz)\" = ok ]"
check "Backend API responds (login)"           bash -c "[ -n '${TOKEN}' ]"
check "Backend->DB works (dashboard)"          bash -c "curl -fsS -H '$H' -H 'Authorization: Bearer ${TOKEN}' ${BASE}/api/dashboard | grep -q total_employees"
check "Postgres StatefulSet ready"             bash -c "kubectl -n ${NS} get statefulset ${FULL}-postgres -o jsonpath='{.status.readyReplicas}' | grep -q 1"
check "Postgres PVC bound"                     bash -c "kubectl -n ${NS} get pvc -o jsonpath='{.items[0].status.phase}' | grep -q Bound"
check "Backend HPA present + reading metrics"  bash -c "kubectl -n ${NS} get hpa ${FULL}-backend -o jsonpath='{.status.currentMetrics}' | grep -q averageUtilization"
check "PDBs present (backend+frontend)"        bash -c "[ \$(kubectl -n ${NS} get pdb --no-headers | wc -l) -ge 2 ]"
check "NetworkPolicies present (>=5)"          bash -c "[ \$(kubectl -n ${NS} get netpol --no-headers | wc -l) -ge 5 ]"
check "ConfigMap mounted (LOG_LEVEL in pod)"   bash -c "kubectl -n ${NS} exec deploy/${FULL}-backend -- printenv LOG_LEVEL | grep -q ."
check "Secret mounted (DATABASE_URL in pod)"   bash -c "kubectl -n ${NS} exec deploy/${FULL}-backend -- printenv DATABASE_URL | grep -q postgresql"
check "Backend runs as non-root"               bash -c "[ \"\$(kubectl -n ${NS} exec deploy/${FULL}-backend -- id -u)\" != 0 ]"
check "Resource requests+limits set"           bash -c "kubectl -n ${NS} get deploy ${FULL}-backend -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' | grep -q ."
check "Replicas spread across nodes"           bash -c "[ \$(kubectl -n ${NS} get pods -l app.kubernetes.io/component=frontend -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\n' | sort -u | wc -l) -ge 2 ]"

echo; log "Result: ${pass} passed, ${fail} failed."
exit "${fail}"
