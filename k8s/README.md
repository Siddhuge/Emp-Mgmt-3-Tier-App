# Kubernetes deployment — three equivalent options

The app can be deployed via **Helm**, **plain manifests**, or **Kustomize**. All
three describe the same resources; the Helm chart is the source of truth and the
other two are generated from it (`make k8s-manifests`).

```
helm/employee-management/     # Helm chart (source of truth)
k8s/
├── manifests/                # plain YAML — kubectl apply -f
└── kustomize/
    ├── base/                 # base = same resources + kustomization.yaml
    └── overlays/
        ├── dev/  stage/  prod/
```

## Dynamic values (placeholders)

Because the registry and Key Vault coordinates are per-environment and created at
apply time, the manifests use `envsubst` placeholders — substitute them from
`terraform output` at deploy:

| Placeholder | From |
| --- | --- |
| `${REGISTRY}` | `terraform output -raw acr_login_server` |
| `${KV_NAME}` | `terraform output -raw key_vault_name` |
| `${KV_TENANT_ID}` | `terraform output -raw tenant_id` |
| `${KV_CLIENT_ID}` | `terraform output -raw kv_identity_client_id` |

> The `$(POSTGRES_USER)` etc. in `DATABASE_URL` are **Kubernetes** env references,
> not placeholders — restrict envsubst to the four vars above so it leaves them alone.

## Option A — Helm (recommended)

```bash
helm upgrade --install ems helm/employee-management -n employee-dev --create-namespace \
  -f helm/employee-management/values-dev.yaml \
  --set image.registry=$ACR $(terraform output -raw helm_keyvault_set_flags)
```

## Option B — plain manifests

```bash
export REGISTRY=... KV_NAME=... KV_TENANT_ID=... KV_CLIENT_ID=...
# namespace + all resources into employee-management:
kubectl apply -f k8s/manifests/00-namespace.yaml
for f in k8s/manifests/*.yaml; do
  envsubst '${REGISTRY} ${KV_NAME} ${KV_TENANT_ID} ${KV_CLIENT_ID}' < "$f"
  echo '---'
done | kubectl apply -n employee-management -f -
```

## Option C — Kustomize (per-environment overlays)

```bash
export REGISTRY=... KV_NAME=... KV_TENANT_ID=... KV_CLIENT_ID=...
kubectl kustomize k8s/kustomize/overlays/dev \
  | envsubst '${REGISTRY} ${KV_NAME} ${KV_TENANT_ID} ${KV_CLIENT_ID}' \
  | kubectl apply -f -
```

What each overlay changes vs. the base:

| | namespace | ingress host | TLS issuer | log level | HPA min/max | resources |
| --- | --- | --- | --- | --- | --- | --- |
| **dev** | employee-dev | employee.dev.sidhuge.xyz | letsencrypt-prod | debug | 2–5 | small |
| **stage** | employee-stage | employee.stage.sidhuge.xyz | letsencrypt-staging | info | 3–8 | base |
| **prod** | employee-prod | employee.sidhuge.xyz | letsencrypt-prod + force-ssl | warning | 3–10 | base |

## Prerequisites (same as Helm)

The cluster needs: an ingress controller, cert-manager + ClusterIssuers
(`manifests/cluster-issuers.yaml`), the Key Vault Secrets Store CSI driver
(AKS add-on, enabled by Terraform), and the workload-identity federation
(Terraform). Secrets are pulled from Key Vault — nothing sensitive is committed.

## Regenerating (keep everything in sync)

`k8s/manifests` and `k8s/kustomize/base` are generated from the chart. After any
chart change:

```bash
make k8s-manifests
kubectl kustomize k8s/kustomize/overlays/dev >/dev/null   # sanity check
```

> Note: the hard pod-anti-affinity that the Helm chart applies in prod
> (`podAntiAffinity: hard`) is not encoded as a prod-overlay patch — add one if
> you deploy prod via Kustomize, or use Helm for prod.
