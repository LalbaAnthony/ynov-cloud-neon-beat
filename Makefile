# Makefile d'exploitation de la plateforme Neon Beat (multi-region).
# Usage : `make <cible> REGION=eu-west`
#
# Prerequis : kubectl, helm, kustomize (ou kubectl >= 1.27 avec kustomize integre).
# Chaque region correspond a un cluster Kubernetes distinct : positionner le bon
# contexte kube avant d'appliquer (`kubectl config use-context <cluster-region>`).

REGION ?= eu-west
OVERLAY := k8s/overlays/$(REGION)

.PHONY: help platform render apply diff delete monitoring keda ingress cert-manager external-secrets

help: ## Affiche cette aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

## --- Addons de plateforme (a installer une fois par cluster/region) ---

platform: ingress cert-manager keda external-secrets monitoring ## Installe tous les addons de plateforme

ingress: ## Controleur d'entree NGINX (support WS/SSE, hachage consistant)
	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
		--namespace neon-ingress --create-namespace \
		--set controller.metrics.enabled=true \
		--set controller.config.use-forwarded-headers=true \
		--set controller.service.externalTrafficPolicy=Local

cert-manager: ## Gestion automatique des certificats TLS
	helm repo add jetstack https://charts.jetstack.io
	helm upgrade --install cert-manager jetstack/cert-manager \
		--namespace cert-manager --create-namespace \
		--set crds.enabled=true

keda: ## Autoscaling evenementiel (scale sur metriques metier)
	helm repo add kedacore https://kedacore.github.io/charts
	helm upgrade --install keda kedacore/keda --namespace keda --create-namespace

external-secrets: ## Synchronisation des secrets depuis le gestionnaire cloud
	helm repo add external-secrets https://charts.external-secrets.io
	helm upgrade --install external-secrets external-secrets/external-secrets \
		--namespace external-secrets --create-namespace

monitoring: ## Stack Prometheus + Grafana + Alertmanager
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
		--namespace neon-observability --create-namespace \
		-f platform/monitoring-values.yaml

## --- Application Neon Beat ---

render: ## Rend les manifestes de la region (dry-run local)
	kubectl kustomize $(OVERLAY)

diff: ## Diff entre l'etat cible et le cluster
	kubectl diff -k $(OVERLAY) || true

apply: ## Applique les manifestes de la region sur le cluster courant
	kubectl apply -k $(OVERLAY)

delete: ## Supprime les ressources applicatives de la region
	kubectl delete -k $(OVERLAY)
