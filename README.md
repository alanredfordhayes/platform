# Platform

A GitOps platform repository for managing Kubernetes infrastructure using Argo CD and HashiCorp Vault. This repository provides automated installation, configuration, and management tools for Argo CD and Vault in Minikube environments, along with comprehensive documentation and App of Apps pattern implementations.

## 🚀 Quick Start

### Install Argo CD in Minikube

```bash
# Quick install (idempotent - safe to run multiple times)
./argocd/install-argocd-minikube.sh install

# Or use the Cursor command
/install-argocd-minikube
```

### Install Vault in Minikube

```bash
# Quick install (idempotent - safe to run multiple times)
./vault/install-vault-minikube.sh install

# Or use the Cursor command
/install-vault-minikube
```

### Bootstrap Cluster with App of Apps Pattern

```bash
# Follow the interactive guide
/bootstrap-cluster-app-of-apps
```

## 📁 Repository Structure

```
platform/
├── argocd/                          # Argo CD installation and configuration
│   ├── install-argocd-minikube.sh   # Automated installation script
│   └── app-of-apps/                  # App of Apps pattern implementation
│       ├── apps/                     # Application manifests
│       │   ├── automation-parent.yaml  # Automation parent app definition
│       │   ├── argocd-child.yaml       # Argo CD child app
│       │   ├── security-parent.yaml   # Security parent app definition
│       │   └── vault.yaml             # Vault child app
│       ├── templates/                # Helm templates (if needed)
│       └── README.md                 # App of Apps quick start
├── vault/                            # Vault installation and configuration
│   ├── install-vault-minikube.sh    # Automated installation script
│   ├── helm-values/                  # Helm values configuration
│   │   └── vault-values.yaml         # HA configuration with Integrated Storage
│   └── README.md                     # Vault quick start
├── doc/                              # Comprehensive documentation
│   ├── README.md                     # Documentation index
│   ├── argocd-installation.md        # Complete installation guide
│   ├── argocd-quick-reference.md     # Quick reference guide
│   └── vault-deployment.md           # Vault deployment guide
└── .cursor/                          # Cursor IDE commands
    └── commands/
        ├── install-argocd-minikube.md      # Installation command
        ├── install-vault-minikube.md       # Vault installation command
        └── bootstrap-cluster-app-of-apps.md # App of Apps command
```

## 🎯 Features

### Argo CD Installation

- **Automated Installation Script**: Idempotent script for installing Argo CD in Minikube
  - Handles existing installations gracefully
  - Automatic cleanup of duplicate/stuck pods
  - Comprehensive error handling and diagnostics
  - Support for custom namespaces

- **Installation Commands**:
  ```bash
  ./argocd/install-argocd-minikube.sh install    # Install Argo CD
  ./argocd/install-argocd-minikube.sh uninstall  # Remove Argo CD
  ./argocd/install-argocd-minikube.sh status      # Check status
  ./argocd/install-argocd-minikube.sh -n <ns>    # Custom namespace
  ```

### Vault Installation

- **Automated Installation Script**: Idempotent script for installing Vault in Minikube
  - Handles existing installations gracefully
  - Helm-based installation with HA configuration
  - Integrated Storage (Raft) backend
  - Automatic Vault initialization attempt
  - Support for custom namespaces

- **Installation Commands**:
  ```bash
  ./vault/install-vault-minikube.sh install    # Install Vault
  ./vault/install-vault-minikube.sh uninstall  # Remove Vault
  ./vault/install-vault-minikube.sh status      # Check status
  ./vault/install-vault-minikube.sh -n <ns>    # Custom namespace
  ```

- **Key Features**:
  - High Availability with 5 replicas (configurable)
  - Integrated Storage using Raft consensus
  - Anti-affinity rules for pod distribution
  - Persistent storage for data durability
  - Vault UI enabled by default

### App of Apps Pattern

- **Automated Cluster Bootstrapping**: Set up GitOps-managed infrastructure
  - Parent applications manage child applications
    - `automation` parent app manages Argo CD
    - `security` parent app manages Vault
  - Argo CD manages itself via GitOps
  - Includes fixes for CRD annotation size limit errors
  - Server-side apply and replace sync options

- **Key Features**:
  - Automated discovery of child applications from Git
  - Proper handling of Argo CD managing itself
  - CRD annotation size limit error fixes
  - Comprehensive troubleshooting guides
  - Separate parent apps for different application categories

## 📚 Documentation

### Quick Links

- **[Argo CD Installation Guide](doc/argocd-installation.md)** - Complete guide for Argo CD installation, architecture, and management
- **[Argo CD Quick Reference](doc/argocd-quick-reference.md)** - Command cheat sheet and common operations
- **[Vault Deployment Guide](doc/vault-deployment.md)** - Complete guide for Vault installation, HA configuration, and security best practices
- **[App of Apps Guide](argocd/app-of-apps/README.md)** - Quick start for App of Apps pattern
- **[Documentation Index](doc/README.md)** - Full documentation index

### Cursor Commands

This repository includes Cursor IDE commands for streamlined workflows:

- **`/install-argocd-minikube`** - Interactive Argo CD installation guide
  - Automated installation steps
  - Troubleshooting tips
  - Lessons learned from deployment

- **`/install-vault-minikube`** - Interactive Vault installation guide
  - Automated installation with Helm
  - Initialization and unsealing instructions
  - HA configuration and troubleshooting

- **`/bootstrap-cluster-app-of-apps`** - App of Apps pattern setup
  - Step-by-step parent/child app creation
  - CRD error fixes and solutions
  - Complete troubleshooting guide

## 🛠️ Installation Script Features

The `install-argocd-minikube.sh` script provides:

### Installation Features
- ✅ Prerequisites checking (minikube, kubectl)
- ✅ Automatic minikube startup
- ✅ Context verification and switching
- ✅ Idempotent installation (safe to run multiple times)
- ✅ Duplicate pod detection and cleanup
- ✅ Individual resource readiness checks
- ✅ Admin password retrieval with retry logic
- ✅ Comprehensive status reporting

### Uninstallation Features
- ✅ Confirmation prompts
- ✅ Complete resource cleanup
- ✅ CRD removal
- ✅ Cluster-level resource cleanup
- ✅ Namespace deletion

### Status Features
- ✅ Pod health and readiness
- ✅ Service status
- ✅ Admin password instructions

## 🏗️ App of Apps Pattern

The App of Apps pattern allows you to declaratively manage multiple Argo CD applications through a parent application.

### Structure

```
automation (Parent App)
    └── argocd (Child App)
            └── Manages Argo CD installation
```

### Key Configuration

The implementation includes lessons learned from production deployments:

- **Server-Side Apply**: `ServerSideApply: true` for large resources
- **Replace Sync Option**: `Replace=true` to avoid CRD annotation size limits
- **Ignore Differences**: Proper configuration for secrets, configmaps, and CRDs
- **Safety Settings**: `prune: false` and `selfHeal: false` for critical infrastructure

### Files

- `argocd/app-of-apps/apps/automation-parent.yaml` - Parent application manifest
- `argocd/app-of-apps/apps/argocd-child.yaml` - Argo CD child application with all fixes

## 🔧 Prerequisites

- **Minikube**: Installed and configured (script will start if needed)
- **kubectl**: Installed and configured
- **Helm 3**: Required for Vault installation (Helm 2 not compatible)
- **Git**: For managing the repository
- **Argo CD CLI** (optional): For command-line access

## 📖 Usage Examples

### Basic Installation

```bash
# Install Argo CD
./argocd/install-argocd-minikube.sh install

# Access the UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080
```

### App of Apps Setup

```bash
# 1. Install Argo CD first
./argocd/install-argocd-minikube.sh install

# 2. Apply parent apps
kubectl apply -f argocd/app-of-apps/apps/automation-parent.yaml
kubectl apply -f argocd/app-of-apps/apps/security-parent.yaml

# 3. Sync parent apps (discovers child apps from Git)
argocd app sync automation
argocd app sync security
```

### Vault Setup

```bash
# 1. Install Vault
./vault/install-vault-minikube.sh install

# 2. Initialize and unseal Vault (see Vault documentation)
# 3. Access Vault UI via port-forward
kubectl port-forward -n vault svc/vault 8200:8200
```

### Custom Namespace

```bash
# Install Argo CD in custom namespace
./argocd/install-argocd-minikube.sh -n my-argocd install

# Install Vault in custom namespace
./vault/install-vault-minikube.sh -n my-vault install
```

## 🐛 Troubleshooting

### Common Issues

**Argo CD:**
1. **Port Conflicts**: Script automatically handles duplicate pods
2. **CrashLoopBackOff**: Check logs with `kubectl logs <pod-name> -n argocd`
3. **Admin Password**: Script includes retry logic; manual retrieval available
4. **CRD Annotation Errors**: See [App of Apps documentation](.cursor/commands/bootstrap-cluster-app-of-apps.md#crd-annotation-size-limit-error)

**Vault:**
1. **Pods Not Starting**: Check resource constraints and storage class
2. **Vault Sealed**: Unseal each pod with 3 unseal keys
3. **Storage Issues**: Verify persistent volume claims and storage class
4. **Initialization Failed**: Initialize manually if automatic initialization fails

### Getting Help

- **Argo CD**: Check the [Installation Guide](doc/argocd-installation.md#troubleshooting) and [Quick Reference](doc/argocd-quick-reference.md)
- **Vault**: Check the [Vault Deployment Guide](doc/vault-deployment.md#troubleshooting)
- **App of Apps**: See [App of Apps Troubleshooting](.cursor/commands/bootstrap-cluster-app-of-apps.md#troubleshooting)

## 🎓 Lessons Learned

This repository includes practical lessons learned from real deployments:

### CRD Annotation Size Limit Error
- **Error**: `CustomResourceDefinition "applicationsets.argoproj.io" is invalid: metadata.annotations: Too long`
- **Solution**: Use `ServerSideApply: true` and `Replace=true` sync options
- **Prevention**: Add `ignoreDifferences` for CRD annotations

### Managing Argo CD with Argo CD
- Use `prune: false` and `selfHeal: false` to prevent accidental deletion
- Configure `ignoreDifferences` for secrets and configmaps
- Always use server-side apply for large resources

### Vault Deployment Considerations
- **Initialization Required**: Vault must be initialized before use (generates unseal keys)
- **Unsealing Required**: Each pod must be unsealed with 3 unseal keys
- **Storage Requirements**: Ensure sufficient storage for persistent volumes (10Gi per pod)
- **Resource Constraints**: 5 replicas may require significant resources in minikube
- **Auto-Unseal**: For production, configure KMS/HSM auto-unseal to avoid manual unsealing
- **Secret Management**: Unseal keys and root tokens must be stored securely (never in Git)

See the [Argo CD Installation Guide](doc/argocd-installation.md), [Vault Deployment Guide](doc/vault-deployment.md), and [App of Apps Guide](.cursor/commands/bootstrap-cluster-app-of-apps.md) for complete details.

## 🔒 Security Notes

- **App of Apps is an admin-only tool** - Only admins should have push access to the parent Application's source repository
- **Review Pull Requests** - Always review PRs, especially the project field in each Application
- **Non-HA Installation** - Argo CD setup is for evaluation/testing, not production
- **Vault HA Installation** - Vault is configured for HA but requires proper initialization and unsealing
- **Cluster Admin Access** - Installation requires cluster-admin access
- **Vault Secrets** - Never commit unseal keys or root tokens to Git

## 📝 Contributing

When adding new features or documentation:

1. Follow existing code structure and patterns
2. Update relevant documentation
3. Include troubleshooting sections
4. Test in Minikube environment
5. Document lessons learned

## 🔗 Additional Resources

- [Argo CD Official Documentation](https://argo-cd.readthedocs.io/)
- [Argo CD GitHub Repository](https://github.com/argoproj/argo-cd)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)

## 📄 License

This repository contains configuration and documentation for Argo CD. Refer to the [Argo CD license](https://github.com/argoproj/argo-cd/blob/master/LICENSE) for Argo CD itself.

---

**Note**: This is a non-HA installation suitable for evaluation, demonstrations, and testing. For production use, consider the HA installation or Argo CD Operator.
