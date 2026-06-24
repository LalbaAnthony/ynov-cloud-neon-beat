# Neon Beat - Dimensionnement et planification de capacité

Document de référence pour le calibrage de l'autoscaling et des quotas. Les valeurs servent de point de départ mais elles devrait être affinées par des tests de charge (voir partie 5 pour ça).

## 1. Charge cible

| Paramètre                                          | Valeur                                |
| -------------------------------------------------- | ------------------------------------- |
| Joueurs simultanés (pic)                           | environ 10 000                        |
| Joueurs cumulés / semaine                          | environ 100 000                       |
| Connexions temps réel par joueur                   | environ 2 (WS buzzer + SSE affichage) |
| Connexions concurrentes (pic, avec écrans + admin) | environ 25 000                        |
| Joueurs par partie (moyenne)                       | 8                                     |
| Parties simultanées (pic)                          | environ 1 250                         |

## 2. Budget par pod game-server

| Ressource                           | Valeur        | Commentaire                                                |
| ----------------------------------- | ------------- | ---------------------------------------------------------- |
| CPU request / limit                 | 500 m / 2     | Le CPU n'est pas le facteur limitant                       |
| Mémoire request / limit             | 512 Mi / 1 Gi | environ 1 Gi pour 40 parties, marge pour le GC et les pics |
| Parties par pod (cible autoscaling) | 40            | Plafond dur applicatif : 50 ( etp puis marge 20 %)         |
| Connexions par pod (garde-fou)      | environ 1 600 | Seuil secondaire KEDA                                      |

## 3. Nombre de pods au pic

| Méthode de calcul                   | Résultat                      |
| ----------------------------------- | ----------------------------- |
| Par les parties : 1 250 / 40        | environ 32 pods               |
| Par les connexions : 25 000 / 1 600 | environ 16 pods               |
|                                     | **environ 32 pods (parties)** |

Répartition indicative selon la part de trafic par région (à ajuster selon les statistiques réelles) :

| Région       | Part du trafic | Pods au pic | `minReplicaCount` | `maxReplicaCount` |
| ------------ | -------------- | ----------- | ----------------- | ----------------- |
| eu-west      | 45 %           | environ 15  | 3                 | 60                |
| us-east      | 35 %           | environ 12  | 3                 | 60                |
| ap-southeast | 20 %           | environ 7   | 3                 | 60                |

> `maxReplicaCount` est volontairement large (60) : il sert en cas de déséquilibre régional sans nécessiter de refaire la conf

## 4. Noeuds

- Type indicatif : 4 vCPU / 8–16 Gi, multi-AZ (>= 3 zones).
- Avec `limit` CPU à 2 et mémoire à 1 Gi, un noeud 4 vCPU / 8 Gi héberge ~6–8 pods game-server 
- 32 pods au pic => ~5–6 noeuds dédiés au game-server, répartis mondialement, + les noeuds de plateforme (ingress, observabilité).
- Le Cluster Autoscaler / Karpenter ajuste le nombre de noeuds selon la pression des pods en attente.

## 5. Tests de charge recommandés

| Test                        | Outil                               | Objectif                                        |
| --------------------------- | ----------------------------------- | ----------------------------------------------- |
| Montée en connexions WS/SSE | -                                   | Valider le budget connexions/pod                |
| Rafale de buzz              | -                                   | Mesurer la latence d'arbitrage p99 sous charge  |
| Bascule de pod              | -                                   | Vérifier le *drain* contrôlé et la reconnexion  |
| Pic d'arrivée               | montée 0 -> 10 000 joueurs en 5 min | Valider la réactivité KEDA + Cluster Autoscaler |

## 6. Hypothèses et les limites

- Le budget "50 parties/pod" est une **hypothèse à confirmer** par le test de charge (partie d'avant) ; il dépend de l'implémentation multi-parties (évolution voir `architecture.md`, partie 13).
- Le nombre de connexions par joueur peut augmenter (spectateurs, reconnexions) faut prévoir une marge.
- Les coûts suivent l'usage réel grâce à l'autoscaling et (3 pods × 3 régions) constitue le coût plancher.
