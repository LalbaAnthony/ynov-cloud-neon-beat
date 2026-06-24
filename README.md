# Neon Beat — Livrable « Déploiement Cloud » (TP M2 DEV CLOUD)

Stratégie de déploiement mondial de Neon Beat sur Kubernetes pour
**10 000 joueurs simultanés** (pic **100 000 / semaine**).

## Contenu du livrable

| Élément                         | Fichier                                           | Correspondance grille |
| ------------------------------- | ------------------------------------------------- | --------------------- |
| Document d'architecture (→ PDF) | [`ARCHITECTURE.md`](ARCHITECTURE.md)              | Livrable PDF /20      |
| Manifests IaC (→ ZIP)           | [`k8s/`](k8s/) + [`k8s/README.md`](k8s/README.md) | Livrable ZIP YAML /20 |

Les schémas d'architecture (composants, déploiement multi-région, séquences
création de partie / buzz, scalabilité, sécurité, monitoring) sont en **Mermaid**
directement dans `ARCHITECTURE.md` et rendus dans le PDF.

## Idée directrice (résumé)

Le backend Neon Beat est **stateful et mono-partie** (FSM + hubs SSE + map des
buzzers en mémoire, SSE admin mono-connexion). On ne peut donc pas le répliquer
derrière un simple load balancer round-robin. La solution traite chaque partie
comme un **serveur de jeu dédié** orchestré par **Agones**, derrière un **edge
stateless** mondial (CDN + matchmaker + passerelle temps réel à routage
*sticky*) et une couche **CouchDB multi-région**. Voir `ARCHITECTURE.md` §1–§3.

## Appliquer l'infrastructure

Voir [`k8s/README.md`](k8s/README.md) (prérequis add-ons, ordre d'application,
finalisation du cluster CouchDB).
