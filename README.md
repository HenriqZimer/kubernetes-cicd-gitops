# 🔄 Kubernetes CI/CD & GitOps Stack

[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.25+-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Helm](https://img.shields.io/badge/Helm-v3.10+-0F1689?logo=helm&logoColor=white)](https://helm.sh/)
[![Jenkins](https://img.shields.io/badge/Jenkins-5.8.114-D24939?logo=jenkins&logoColor=white)](https://www.jenkins.io/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-7.8.6-EF7B4D?logo=argo&logoColor=white)](https://argo-cd.readthedocs.io/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A production-ready GitOps and CI/CD stack for Kubernetes, featuring Jenkins, Harbor, SonarQube, and ArgoCD.

## 🎯 Overview

This repository provides a complete GitFlow workflow infrastructure deployed on Kubernetes using Helm and Helmfile. It implements industry best practices for continuous integration, delivery, and GitOps-based deployments.

### Key Features

- **🔄 Complete CI/CD Pipeline**: Automated build, test, and deployment workflows
- **🐳 Container Registry**: Private Docker registry with Harbor
- **📊 Code Quality**: Integrated code analysis with SonarQube
- **🚀 GitOps Deployments**: ArgoCD for declarative continuous delivery
- **🔐 Secret Management**: Integration with External Secrets Operator and Vault
- **💾 Persistent Storage**: NFS-based persistent volumes for stateful applications
- **🔧 Automation**: Comprehensive Makefile for streamlined operations

## 📦 Components

| Component | Version | Purpose |
|-----------|---------|---------|
| **Jenkins** | 5.8.114 | CI/CD automation server |
| **Harbor** | 1.18.0 | Container image registry |
| **SonarQube** | 10.8.0 | Code quality and security platform |
| **ArgoCD** | 7.8.6 | GitOps continuous delivery |
| **Image Pull Secret Patcher** | Latest | Automatically patches image pull secrets |

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌──────────┐   │
│  │ Jenkins  │  │  Harbor  │  │ SonarQube │  │  ArgoCD  │   │
│  │          │  │          │  │           │  │          │   │
│  │ CI/CD    │  │ Registry │  │ Code QA   │  │ GitOps   │   │
│  └────┬─────┘  └────┬─────┘  └─────┬─────┘  └────┬─────┘   │
│       │             │               │             │          │
│  ┌────┴─────────────┴───────────────┴─────────────┴─────┐   │
│  │          External Secrets Operator + Vault           │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         NFS Persistent Storage (StatefulSets)        │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Prerequisites

Before deploying this stack, ensure you have:

- **Kubernetes Cluster** (v1.25+)
  - 3+ worker nodes recommended
  - External Secrets Operator installed
  - MetalLB or another LoadBalancer solution

- **Storage**
  - NFS server configured and accessible
  - StorageClass `nfs-static` available

- **Tools**
  - `kubectl` (v1.25+)
  - `helm` (v3.10+)
  - `helmfile` (v0.150+)
  - `make`

- **Secrets Management**
  - Vault server running and configured
  - ClusterSecretStore `vault-backend` configured

## 🚀 Quick Start

### 1. Clone and Configure

```bash
cd k8s-gitflow
```

### 2. Review Configuration

Edit the values files in `values/` directory to match your environment:

```bash
# Update NFS server details
vim values/jenkins/values.yaml
vim values/harbor/values.yaml
vim values/sonarqube/values.yaml
```

### 3. Deploy Everything

```bash
make deploy
```

This command will:
1. Create namespaces
2. Configure persistent volumes
3. Apply external secrets
4. Deploy all applications via Helmfile

### 4. Check Deployment Status

```bash
make status
```

## 📚 Usage

### Available Make Targets

Run `make help` to see all available commands:

```bash
make help
```

Key targets:

| Target | Description |
|--------|-------------|
| `make deploy` | Full deployment from scratch |
| `make status` | Check deployment status |
| `make validate` | Validate Kubernetes manifests |
| `make clean` | Remove all resources (destructive) |
| `make logs-jenkins` | View Jenkins logs |
| `make port-forward-jenkins` | Port-forward to Jenkins (8080) |
| `make argocd-apps` | Deploy ArgoCD applications |

### Accessing Applications

After deployment, access applications using configured Ingress or port-forwarding:

```bash
# Jenkins
make port-forward-jenkins
# Access at http://localhost:8080

# Harbor
make port-forward-harbor
# Access at http://localhost:8081

# SonarQube
make port-forward-sonarqube
# Access at http://localhost:9000

# ArgoCD
make port-forward-argocd
# Access at https://localhost:8082
```

### Retrieving Admin Credentials

Credentials are managed by External Secrets and stored in Vault. To retrieve them:

```bash
# Jenkins
kubectl get secret jenkins-admin-credentials -n jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d

# Harbor
kubectl get secret harbor-admin-password -n harbor -o jsonpath='{.data.HARBOR_ADMIN_PASSWORD}' | base64 -d

# SonarQube
kubectl get secret sonarqube-admin-credentials -n sonarqube -o jsonpath='{.data.password}' | base64 -d

# ArgoCD
kubectl get secret argocd-secret -n argocd -o jsonpath='{.data.password}' | base64 -d
```

## 🔧 Configuration

### Persistent Volumes

All persistent volumes are pre-created and bound to specific applications:

**Jenkins:**
- `jenkins-pv`: 8Gi (application data)
- `jenkins-artifacts-pv`: 1Gi (build artifacts)

**Harbor:**
- `harbor-postgresql-pv`: 10Gi (database)
- `harbor-registry-pv`: 5Gi (container images)
- `harbor-redis-pv`: 1Gi (cache)
- `harbor-jobservice-pv`: 1Gi (job logs)
- `harbor-trivy-pv`: 5Gi (vulnerability scanner)

**SonarQube:**
- `sonarqube-pv`: 5Gi (application data)
- `sonarqube-postgresql-pv`: 20Gi (database)

### NFS Configuration

Update NFS server details in `manifests/persistent-volume.yaml`:

```yaml
nfs:
  server: your-nfs-server.local
  path: /mnt/storage/kubernetes/jenkins
```

### External Secrets

Secrets are synchronized from Vault using External Secrets Operator. Configure the Vault backend in your cluster's ClusterSecretStore:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "http://vault.vault.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
```

## 🔐 Security Best Practices

This repository implements several Kubernetes security best practices:

- ✅ **No Hardcoded Secrets**: All sensitive data managed via External Secrets
- ✅ **RBAC Configured**: Service accounts with minimal required permissions
- ✅ **Network Policies**: (Configure in your cluster as needed)
- ✅ **Pod Security Standards**: SecurityContexts configured for containers
- ✅ **Image Pull Secrets**: Automatically patched across namespaces
- ✅ **TLS/SSL**: Certificate management with cert-manager integration

### Security Checklist

Before production deployment:

- [ ] Review and update all default configurations
- [ ] Configure proper RBAC policies
- [ ] Enable network policies
- [ ] Set up proper TLS certificates
- [ ] Configure backup strategies
- [ ] Review pod security contexts
- [ ] Set resource limits and requests
- [ ] Configure monitoring and alerting

## 📊 Monitoring

The stack integrates with Prometheus and Grafana (if deployed in your cluster):

- Jenkins metrics via Prometheus plugin
- Harbor metrics endpoint
- SonarQube webhook notifications
- ArgoCD application health

## 🔄 GitOps Workflow

### Typical Development Flow

1. **Developer** pushes code to Gitea
2. **Jenkins** triggers pipeline
3. **Build** and run tests
4. **SonarQube** performs code quality analysis
5. **Harbor** stores container images
6. **ArgoCD** deploys to Kubernetes
7. **Monitoring** tracks application health

### ArgoCD Applications

Deploy sample applications:

```bash
make argocd-apps
```

This creates ArgoCD applications for:
- Development environment
- Staging environment
- Production environment

## 🛠️ Troubleshooting

### Common Issues

**Pods stuck in Pending:**
```bash
kubectl describe pod <pod-name> -n <namespace>
# Check for PVC binding issues or resource constraints
```

**External Secrets not syncing:**
```bash
kubectl get externalsecrets -A
kubectl describe externalsecret <name> -n <namespace>
# Verify Vault connectivity and permissions
```

**NFS mount issues:**
```bash
# Check NFS server accessibility
showmount -e <nfs-server>

# Verify permissions on NFS directories
ls -la /mnt/storage/kubernetes/
```

### Logs

View logs for specific components:

```bash
# Jenkins
make logs-jenkins

# Harbor
make logs-harbor

# SonarQube
make logs-sonarqube

# ArgoCD
make logs-argocd
```

## 🔄 Upgrading

To upgrade components:

```bash
# Update chart version in helmfile.yaml
vim helmfile.yaml

# Apply changes
helmfile apply
```

## 🧹 Cleanup

To remove all deployed resources:

```bash
make clean
```

**⚠️ Warning:** This will delete all applications and persistent data. Ensure you have backups before proceeding.

## 📖 Documentation

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Harbor Documentation](https://goharbor.io/docs/)
- [SonarQube Documentation](https://docs.sonarqube.org/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [External Secrets Documentation](https://external-secrets.io/)

## 📄 License

This project configuration is provided as-is for personal and educational use.

## 🙏 Acknowledgments

Built with open-source components from the Kubernetes ecosystem:
- [Helm](https://helm.sh/)
- [Helmfile](https://helmfile.readthedocs.io/)
- [Jenkins](https://www.jenkins.io/)
- [Harbor](https://goharbor.io/)
- [SonarQube](https://www.sonarqube.org/)
- [ArgoCD](https://argoproj.github.io/argo-cd/)

---

**Note:** This is a personal infrastructure project. Configurations should be reviewed and adapted for your specific environment and security requirements before production use.
