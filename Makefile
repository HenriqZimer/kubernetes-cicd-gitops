.PHONY: help namespaces pvcs cleanup-pvs secrets helm rbac argocd-apps deploy status validate clean logs-jenkins logs-harbor logs-sonarqube logs-argocd port-forward-jenkins port-forward-harbor port-forward-sonarqube port-forward-argocd

# Colors for output
GREEN  := \033[0;32m
YELLOW := \033[0;33m
RED    := \033[0;31m
BLUE   := \033[0;34m
RESET  := \033[0m

# Default target
.DEFAULT_GOAL := help

help: ## Display this help message
	@echo "$(BLUE)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo "$(BLUE)  GitFlow CI/CD Stack - Makefile Help$(RESET)"
	@echo "$(BLUE)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Usage:$(RESET)"
	@echo "  make $(GREEN)deploy$(RESET)        # Full deployment from scratch"
	@echo "  make $(GREEN)status$(RESET)        # Check deployment status"
	@echo "  make $(GREEN)validate$(RESET)      # Validate configurations"
	@echo "  make $(GREEN)clean$(RESET)         # Clean up all resources"
	@echo ""

namespaces: ## Create namespaces
	@echo "$(BLUE)📦 Creating namespaces...$(RESET)"
	@kubectl apply -f manifests/namespace.yaml
	@echo "$(GREEN)✅ Namespaces created$(RESET)"
	@echo ""

cleanup-pvs: ## Release PersistentVolumes stuck in Released state
	@echo "$(BLUE)🔧 Checking and releasing PersistentVolumes...$(RESET)"
	@for pv in jenkins-pv jenkins-artifacts-pv sonarqube-pv sonarqube-postgresql-pv \
	           harbor-registry-pv harbor-postgresql-pv harbor-redis-pv harbor-trivy-pv harbor-jobservice-pv; do \
		if kubectl get pv $$pv >/dev/null 2>&1; then \
			STATUS=$$(kubectl get pv $$pv -o jsonpath='{.status.phase}'); \
			if [ "$$STATUS" = "Released" ]; then \
				echo "  $(YELLOW)🔓 Releasing $$pv...$(RESET)"; \
				kubectl patch pv $$pv --type json -p '[{"op": "remove", "path": "/spec/claimRef"}]' 2>/dev/null || true; \
			fi; \
		fi; \
	done
	@echo "$(GREEN)✅ PersistentVolumes checked$(RESET)"
	@echo ""

pvcs: cleanup-pvs ## Create PersistentVolumes and PersistentVolumeClaims
	@echo "$(BLUE)📦 Creating PersistentVolumes and PersistentVolumeClaims...$(RESET)"
	@kubectl apply -f manifests/persistent-volume.yaml
	@kubectl apply -f manifests/persistent-volume-claim.yaml
	@echo "$(GREEN)✅ PVs and PVCs created$(RESET)"
	@echo ""

secrets: ## Apply ExternalSecrets for retrieving secrets from Vault
	@echo "$(BLUE)🔐 Applying ExternalSecrets...$(RESET)"
	@kubectl apply -f manifests/external-secrets.yaml
	@echo "$(GREEN)✅ ExternalSecrets applied$(RESET)"
	@echo "$(YELLOW)⚠️  Note: Secrets will be created once External Secrets Operator is running$(RESET)"
	@echo ""

helm: namespaces pvcs secrets ## Deploy applications using Helmfile
	@echo "$(BLUE)🚀 Deploying applications with Helmfile...$(RESET)"
	@helmfile apply
	@echo ""
	@echo "$(BLUE)⏳ Waiting for deployments to be ready...$(RESET)"
	@sleep 10
	@echo "$(GREEN)✅ Helmfile deployment completed$(RESET)"
	@echo ""

deploy: helm rbac argocd-apps ## Full deployment (creates everything)
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo "$(GREEN)  ✅ GitFlow Stack Deployment Completed!$(RESET)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(RESET)"
	@echo "  1. Check status: make status"
	@echo "  2. Validate: make validate"
	@echo "  3. View logs: make logs-<service>"
	@echo ""

status: ## Check deployment status
	@echo "$(BLUE)📊 Checking deployment status...$(RESET)"
	@echo ""
	@echo "$(YELLOW)Namespaces:$(RESET)"
	@kubectl get namespaces | grep -E '(jenkins|harbor|sonarqube|argocd|imagepullsecret)' || echo "  No namespaces found"
	@echo ""
	@echo "$(YELLOW)Pods:$(RESET)"
	@kubectl get pods -n jenkins -o wide 2>/dev/null || echo "  Jenkins namespace not found"
	@kubectl get pods -n harbor -o wide 2>/dev/null || echo "  Harbor namespace not found"
	@kubectl get pods -n sonarqube -o wide 2>/dev/null || echo "  SonarQube namespace not found"
	@kubectl get pods -n argocd -o wide 2>/dev/null || echo "  ArgoCD namespace not found"
	@echo ""
	@echo "$(YELLOW)PersistentVolumeClaims:$(RESET)"
	@kubectl get pvc -A | grep -E '(jenkins|harbor|sonarqube)' || echo "  No PVCs found"
	@echo ""
	@echo "$(YELLOW)Ingress:$(RESET)"
	@kubectl get ingress -A | grep -E '(jenkins|harbor|sonarqube|argocd)' || echo "  No Ingress found"
	@echo ""

validate: ## Validate Kubernetes manifests
	@echo "$(BLUE)🔍 Validating Kubernetes manifests...$(RESET)"
	@echo ""
	@for file in manifests/*.yaml manifests/**/*.yaml; do \
		if [ -f "$$file" ]; then \
			echo "$(YELLOW)Validating $$file...$(RESET)"; \
			kubectl apply --dry-run=client -f "$$file" >/dev/null 2>&1 && \
				echo "$(GREEN)  ✓ Valid$(RESET)" || \
				echo "$(RED)  ✗ Invalid$(RESET)"; \
		fi; \
	done
	@echo ""
	@echo "$(GREEN)✅ Validation completed$(RESET)"
	@echo ""

clean: ## Clean up all resources (WARNING: Destructive operation!)
	@echo "$(RED)⚠️  WARNING: This will delete all GitFlow stack resources!$(RESET)"
	@echo "$(YELLOW)Press Ctrl+C to cancel, or wait 5 seconds to continue...$(RESET)"
	@sleep 5
	@echo ""
	@echo "$(BLUE)🗑️  Removing Helm releases...$(RESET)"
	@helmfile destroy || true
	@echo ""
	@echo "$(BLUE)🗑️  Deleting PVCs...$(RESET)"
	@kubectl delete -f manifests/persistent-volume-claim.yaml --ignore-not-found=true || true
	@echo ""
	@echo "$(BLUE)🗑️  Deleting PVs...$(RESET)"
	@kubectl delete -f manifests/persistent-volume.yaml --ignore-not-found=true || true
	@echo ""
	@echo "$(BLUE)🗑️  Deleting ExternalSecrets...$(RESET)"
	@kubectl delete -f manifests/external-secrets.yaml --ignore-not-found=true || true
	@echo ""
	@echo "$(BLUE)🗑️  Deleting namespaces...$(RESET)"
	@kubectl delete -f manifests/namespaces.yaml --ignore-not-found=true || true
	@echo ""
	@echo "$(GREEN)✅ Cleanup completed$(RESET)"
	@echo ""

rbac: ## Apply Jenkins RBAC configurations
	@echo "$(BLUE)🔒 Applying Jenkins RBAC...$(RESET)"
	@kubectl apply -f manifests/jenkins-rbac.yaml
	@echo "$(GREEN)✅ RBAC configured$(RESET)"
	@echo ""

argocd-apps: ## Deploy ArgoCD Applications
	@echo "$(BLUE)🚀 Deploying ArgoCD Applications...$(RESET)"
	@kubectl apply -f manifests/argo-cd/
	@echo "$(GREEN)✅ ArgoCD Applications deployed$(RESET)"
	@echo ""

logs-jenkins: ## Show Jenkins logs
	@kubectl logs -f -n jenkins statefulset/jenkins

logs-harbor: ## Show Harbor core logs
	@kubectl logs -f -n harbor deployment/harbor-core

logs-sonarqube: ## Show SonarQube logs
	@kubectl logs -f -n sonarqube statefulset/sonarqube-sonarqube

logs-argocd: ## Show ArgoCD server logs
	@kubectl logs -f -n argocd deployment/argocd-server

port-forward-jenkins: ## Port-forward to Jenkins (localhost:8080)
	@echo "$(BLUE)🔌 Port-forwarding to Jenkins on http://localhost:8080$(RESET)"
	@kubectl port-forward -n jenkins svc/jenkins 8080:8080

port-forward-harbor: ## Port-forward to Harbor (localhost:8081)
	@echo "$(BLUE)🔌 Port-forwarding to Harbor on http://localhost:8081$(RESET)"
	@kubectl port-forward -n harbor svc/harbor-portal 8081:80

port-forward-sonarqube: ## Port-forward to SonarQube (localhost:9000)
	@echo "$(BLUE)🔌 Port-forwarding to SonarQube on http://localhost:9000$(RESET)"
	@kubectl port-forward -n sonarqube svc/sonarqube-sonarqube 9000:9000

port-forward-argocd: ## Port-forward to ArgoCD (localhost:8082)
	@echo "$(BLUE)🔌 Port-forwarding to ArgoCD on http://localhost:8082$(RESET)"
	@kubectl port-forward -n argocd svc/argocd-server 8082:443
