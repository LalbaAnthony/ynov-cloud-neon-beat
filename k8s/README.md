# Neon Beat — Kubernetes manifests (IaC deliverable)

Infrastructure-as-Code for the global deployment of Neon Beat. See
[`../ARCHITECTURE.md`](../ARCHITECTURE.md) for the full rationale.

> Manifests and comments are in English (engineering convention). The
> architecture document (PDF) is in French.

## Layout (component breakdown)

| Folder | Component | Key objects |
|---|---|---|
| `00-namespaces/` | Namespaces + Pod Security | `Namespace` (restricted/baseline) |
| `01-edge/` | Stateless edge | frontends (`Deployment`/`Service`), `matchmaker`, `realtime-gateway`, `HPA`, `PDB`, `Ingress` |
| `02-game-tier/` | Stateful game servers | Agones `Fleet`, `FleetAutoscaler`, `GameServerAllocation` (example) |
| `03-data/` | Persistence | CouchDB `StatefulSet` (3-node cluster) + `PDB`, Redis `StatefulSet`, secrets (example) |
| `04-security/` | Security | `cert-manager` issuer/cert, `RBAC`, `NetworkPolicy`, `ResourceQuota`/`LimitRange` |
| `05-observability/` | Monitoring | `ServiceMonitor`/`PodMonitor`, `PrometheusRule`, Grafana dashboard |

## Prerequisites (cluster add-ons)

These provide the CRDs the manifests reference. Install **before** applying:

```bash
# Agones (game server orchestration)
helm repo add agones https://agones.dev/chart/stable
helm install agones agones/agones -n agones-system --create-namespace

# Ingress, TLS, observability, custom-metrics HPA, secrets
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace
helm install cert-manager jetstack/cert-manager -n cert-manager --create-namespace --set crds.enabled=true
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n neon-observability --create-namespace
helm install prometheus-adapter prometheus-community/prometheus-adapter -n neon-observability   # custom metric: gateway_active_connections
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace
```

Also required: a Cluster Autoscaler enabled on the managed cluster (GKE/EKS/AKS),
multi-AZ node pools, and an `ssd-retain` StorageClass.

## Apply order

```bash
# 1) Copy and fill real secrets (or wire ExternalSecrets), do NOT use the example as-is
cp 03-data/secrets.example.yaml /tmp/secrets.yaml   # edit values
kubectl apply -f /tmp/secrets.yaml

# 2) Everything else via Kustomize (namespaces first is handled by the ordering)
kubectl apply -k .

# 3) One-time CouchDB cluster finalization (see comment in 03-data/couchdb.yaml)
```

> `kubectl apply -k .` is idempotent. If a CRD-dependent object fails on first
> apply because an add-on is still installing, re-run apply once the add-on is
> ready.

## What is intentionally NOT static

- `GameServerAllocation` is created **at runtime** by the matchmaker (one per
  game). `02-game-tier/gameserverallocation-example.yaml` documents the contract.
- Real secrets come from the **External Secrets Operator** / Sealed Secrets, not
  from `secrets.example.yaml`.

## New platform components (not in the existing repos)

`matchmaker` and `realtime-gateway` are new stateless services introduced by this
architecture (images `ghcr.io/neon-beat/matchmaker`, `.../realtime-gateway`).
The Rust backend additionally needs the **Agones SDK** embedded — see
ARCHITECTURE.md §3/§11.
