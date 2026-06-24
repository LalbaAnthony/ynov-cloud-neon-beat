# Neon Beat - Infrastructure cloud

Déploiement cloud mondial de Neon Beat sur Kubernetes en mettant multi-région, équilibrage de charge, autoscaling et supervision.

On va cibler : **10 000 joueurs simultanés**, **100 000 joueurs/semaine**, partout dans le monde, avec une latence faible et homogène.

## Documentation

| Document                                               | Contenu                                                                                        |
| ------------------------------------------------------ | ---------------------------------------------------------------------------------------------- |
| [docs/architecture.md](docs/architecture.md)           | Rapport d'architecture complet (analyse, choix, diagrammes, sécurité, supervision, temps réel) |
| [docs/capacity-planning.md](docs/capacity-planning.md) | Dimensionnement, budgets par pod, autoscaling, tests de charge                                 |

## En bref

Neon Beat maintient l'état d'une partie en mémoire (un processus = une partie). On en déduit une architecture de division par partie :
- chaque partie est épinglée à un pod via un hachage consistant sur `game_id` au niveau de l'Ingress (tout le trafic REST/WS/SSE d'une partie va sur le même pod) ;
- les parties sont ancrées par région (proche des joueurs) ; un DNS géographique route chaque client vers la région la plus proche ;
- la perte d'un pod est tolérée carr l'état est checkpointé en continu en base et rechargé après reconnexion
- l'autoscaling (KEDA) s'appuie sur des métriques métier (parties actives, connexions) et non sur le CPU => plus de robustesse

## Arborescence

```
.
├── README.md
├── Makefile                       # Cibles d'installation et de déploiement
├── docs/
│   ├── architecture.md            # Rapport d'architecture (FR)
│   └── capacity-planning.md       # Dimensionnement
├── platform/
│   └── monitoring-values.yaml     # Valeurs Helm kube-prometheus-stack
└── k8s/
    ├── base/                      # Socle commun (Kustomize)
    │   ├── 00-namespaces.yaml
    │   ├── game-server/           # Backend temps réel (Deployment, HPA/KEDA, PDB, SVC...)
    │   ├── lobby/                 # Plan de contrôle global (game_id -> région)
    │   ├── redis/                 # Registre de sessions + pub/sub
    │   ├── ingress/               # Ingress NGINX (WS/SSE/affinité), cert-manager
    │   ├── networkpolicies/       # Isolation réseau (deny par défaut)
    │   └── monitoring/            # PrometheusRule + dashboard Grafana
    └── overlays/                  # Spécialisations régionales
        ├── eu-west/
        ├── us-east/
        └── ap-southeast/
```

## Prérequis

- `kubectl` >= 1.27 (kustomize intégré), `helm` >= 3.12
- Un cluster Kubernetes **par région** (ex. GKE/EKS dans `europe-west`, `us-east`, `asia-southeast`), chacun avec un node pool multi-AZ et le Cluster Autoscaler activé
- Un cluster **MongoDB Atlas Global** (zone sharding) et un DNS géographique (Cloudflare / Route 53 / Cloud DNS)

> Deux évolutions backend sont des prérequis fonctionnels (multi-parties par > processus, endpoint `/metrics`), détaillées dans > [docs/architecture.md](docs/architecture.md#13-évolutions-nécessaires-côté-applicatif).
> La plateforme reste déployable sans elles en mode "une partie par pod".

## Déploiement

```bash
# 1. Se placer sur le cluster de la région cible
kubectl config use-context <cluster-eu-west>

# 2. Installer les addons de plateforme (une fois par cluster)
make platform REGION=eu-west

# 3. Vérifier le rendu des manifestes applicatifs
make render REGION=eu-west

# 4. Déployer l'application
make apply REGION=eu-west
```

Répéter les étapes 1 à 4 pour `us-east` et `ap-southeast`.

> Les secrets (`MONGO_URI`, token admin) ne sont **pas** versionnés : `k8s/base/game-server/secret.example.yaml` est un example. En prod, ils sont injectés par l'External Secrets Operator depuis le gestionnaire de secrets du cloud.

## Composants principaux

| Composant             | Namespace            | Rôle                                                               |
| --------------------- | -------------------- | ------------------------------------------------------------------ |
| game-server           | `neon-game`          | Backend Rust temps réel (REST + WS + SSE), épinglé par partie      |
| lobby                 | `neon-game`          | Résout `game_id -> région`, ancre les nouvelles parties            |
| redis                 | `neon-data`          | Registre `game_id -> pod` + bus pub/sub                            |
| Ingress NGINX         | `neon-ingress`       | Entrée L7 : WS/SSE, affinité par hachage, TLS, CORS, rate limiting |
| kube-prometheus-stack | `neon-observability` | Prometheus, Grafana, Alertmanager                                  |
