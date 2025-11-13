# Argo CD Installation Guide for Minikube

This guide documents the automated installation, management, and uninstallation of Argo CD in a Minikube environment.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Argo CD Core](#argo-cd-core)
- [Uninstallation](#uninstallation)
- [Status Check](#status-check)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Architecture](#architecture)
- [Script Reference](#script-reference)

## Overview

The `install-argocd-minikube.sh` script provides a fully automated, idempotent solution for managing Argo CD installations in Minikube. It supports:

- **Installation**: Fresh installs and updates to existing installations (full Argo CD stack)
- **Uninstallation**: Complete removal of Argo CD and all associated resources
- **Status**: Quick health check and status reporting
- **Idempotency**: Safe to run multiple times without side effects

**Note**: This guide covers both the **full Argo CD installation** (via the automated script) and **Argo CD Core** (headless mode, manual installation). See the [Argo CD Core](#argo-cd-core) section for details on the minimal installation option.

### Key Features

- ✅ **Idempotent**: Can be run multiple times safely
- ✅ **Independent**: No external dependencies beyond minikube and kubectl
- ✅ **Automated**: Handles all installation steps automatically
- ✅ **Error Handling**: Comprehensive error detection and recovery
- ✅ **Status Reporting**: Detailed feedback on installation progress
- ✅ **Clean Uninstall**: Complete removal of all resources

## Prerequisites

### Required Software

1. **Minikube**: Local Kubernetes cluster
   ```bash
   # Check if installed
   minikube version
   
   # Install (macOS)
   brew install minikube
   ```

2. **kubectl**: Kubernetes command-line tool
   ```bash
   # Check if installed
   kubectl version --client
   
   # Install (macOS)
   brew install kubectl
   ```

### System Requirements

- Minimum 2 CPU cores
- Minimum 2GB RAM (4GB recommended)
- 20GB free disk space
- Internet connection (for downloading images and manifests)

## Quick Start

### Install Argo CD

```bash
# Navigate to the platform directory
cd /path/to/platform

# Run the installation script
./argocd/install-argocd-minikube.sh
```

The script will:
1. Check prerequisites
2. Start minikube if needed
3. Create the `argocd` namespace
4. Apply the Argo CD manifest
5. Wait for all components to be ready
6. Display the admin password

### Access Argo CD UI

After installation:

```bash
# Port forward to access the UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open in browser
open https://localhost:8080
```

**Default Credentials:**
- Username: `admin`
- Password: (displayed by the script after installation)

## Installation

### Basic Installation

```bash
# Default installation (uses 'argocd' namespace)
./argocd/install-argocd-minikube.sh install
```

### Custom Namespace

```bash
# Install in a custom namespace
./argocd/install-argocd-minikube.sh install -n my-argocd

# Or using environment variable
export ARGOCD_NAMESPACE=my-argocd
./argocd/install-argocd-minikube.sh install
```

### Installation Process

The script performs the following steps:

1. **Prerequisites Check**
   - Verifies minikube and kubectl are installed
   - Checks minikube status
   - Validates kubectl context

2. **Environment Setup**
   - Starts minikube if not running
   - Ensures kubectl context is set to minikube
   - Creates namespace if it doesn't exist

3. **Existing Installation Detection**
   - Checks for existing Argo CD installation
   - Cleans up duplicate or stuck pods
   - Handles updates gracefully

4. **Manifest Application**
   - Downloads the official Argo CD manifest
   - Applies all resources to the cluster
   - Handles both new and existing resources

5. **Component Readiness**
   - Waits for deployments to be ready (10-minute timeout per deployment)
   - Waits for statefulsets to be ready (10-minute timeout per statefulset)
   - Reports readiness status

6. **Health Check**
   - Checks pod status
   - Identifies pods in error states
   - Provides diagnostic information

7. **Password Retrieval**
   - Retrieves the initial admin password
   - Retries up to 5 times with 10-second delays
   - Displays credentials for UI access

### Installation Output

The script provides colored, informative output:

- ✓ Green: Success messages
- ✗ Red: Error messages
- ℹ Yellow: Information messages
- ⚠ Blue: Warning messages

Example output:
```
🚀 Argo CD Minikube Installation
==================================

ℹ Checking prerequisites...
✓ Prerequisites check passed
ℹ Checking minikube status...
✓ Minikube is running
ℹ Verifying kubectl context...
✓ Using minikube context: minikube
...
📋 Argo CD Installation Complete!
==========================================

Admin Username: admin
Admin Password: <password>

To access Argo CD UI:
  1. Run: kubectl port-forward svc/argocd-server -n argocd 8080:443
  2. Open: https://localhost:8080
  3. Login with username 'admin' and the password above
```

## Argo CD Core

### Introduction

Argo CD Core is a different installation that runs Argo CD in headless mode. With this installation, you will have a fully functional GitOps engine capable of getting the desired state from Git repositories and applying it in Kubernetes.

**Note**: The standard installation script (`install-argocd-minikube.sh`) installs the full Argo CD stack. Argo CD Core requires manual installation using the core manifest.

### Features Comparison

#### Features Not Available in Core Installation

The following groups of features won't be available in this installation:

- **Argo CD RBAC model** - Core relies on Kubernetes RBAC only
- **Argo CD API** - No centralized API server
- **Argo CD Notification Controller** - Not included in core installation
- **OIDC based authentication** - No external authentication providers

#### Features Partially Available

The following features will be partially available (see the usage section below for more details):

- **Argo CD Web UI** - Can be run locally using `argocd admin dashboard`
- **Argo CD CLI** - Works with `--core` flag, spawns local API server
- **Multi-tenancy** - Strictly GitOps based on git push permissions

### Use Cases

A few use-cases that justify running Argo CD Core are:

1. **Kubernetes RBAC Only**
   - As a cluster admin, I want to rely on Kubernetes RBAC only.

2. **Kubernetes API Only**
   - As a devops engineer, I don't want to learn a new API or depend on another CLI to automate my deployments. I want to rely on the Kubernetes API only.

3. **No UI/CLI Access for Developers**
   - As a cluster admin, I don't want to provide Argo CD UI or Argo CD CLI to developers.

### Architecture

Because Argo CD is designed with a component based architecture in mind, it is possible to have a more minimalist installation. In this case fewer components are installed and yet the main GitOps functionality remains operational.

**Core Components:**
- **Application Controller** - Monitors and syncs applications
- **Repository Server** - Fetches and generates manifests from Git
- **Redis** - Caching mechanism (recommended, reduces load on Kube API and Git)

**Components Not Included:**
- API Server (argocd-server)
- Dex Server (argocd-dex-server)
- Notifications Controller (argocd-notifications-controller)
- Applicationset Controller (argocd-applicationset-controller) - Optional

**Note**: Even if the Argo CD controller can run without Redis, it isn't recommended. The Argo CD controller uses Redis as an important caching mechanism reducing the load on Kube API and in Git. For this reason, Redis is also included in this installation method.

### Installing Argo CD Core

Argo CD Core can be installed by applying a single manifest file that contains all the required resources.

#### Installation Steps

```bash
# Set the desired Argo CD version
export ARGOCD_VERSION=v2.7.0  # Replace with your desired version

# Create the namespace
kubectl create namespace argocd

# Apply the core installation manifest
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/core-install.yaml
```

#### Verify Installation

```bash
# Check pods
kubectl get pods -n argocd

# Check deployments
kubectl get deployments -n argocd

# Check statefulsets
kubectl get statefulsets -n argocd
```

Expected components:
- `argocd-repo-server` (deployment)
- `argocd-application-controller` (statefulset)
- `argocd-redis` (deployment)

### Using Argo CD Core

Once Argo CD Core is installed, users will be able to interact with it by relying on GitOps. The available Kubernetes resources will be the Application and the ApplicationSet CRDs. By using those resources, users will be able to deploy and manage applications in Kubernetes.

#### Managing Applications via Kubernetes API

Since there's no API server, you interact with Argo CD Core using standard Kubernetes resources:

```bash
# Create an Application resource
kubectl apply -f application.yaml

# List applications
kubectl get applications -n argocd

# Get application details
kubectl get application <app-name> -n argocd -o yaml

# Describe application
kubectl describe application <app-name> -n argocd

# Delete application
kubectl delete application <app-name> -n argocd
```

#### Using Argo CD CLI with Core Mode

It is still possible to use Argo CD CLI even when running Argo CD Core. In this case, the CLI will spawn a local API server process that will be used to handle the CLI command. Once the command is concluded, the local API Server process will also be terminated. This happens transparently for the user with no additional command required.

**Important**: Argo CD Core will rely only on Kubernetes RBAC and the user (or the process) invoking the CLI needs to have access to the Argo CD namespace with the proper permission in the Application and ApplicationSet resources for executing a given command.

To use Argo CD CLI in core mode, it is required to pass the `--core` flag with the login subcommand. The `--core` flag is responsible for spawning a local Argo CD API server process that handles CLI and Web UI requests.

**Example:**

```bash
# Set the current context to argocd namespace
kubectl config set-context --current --namespace=argocd

# Login with core mode
argocd login --core

# Now you can use CLI commands normally
argocd app list
argocd app get <app-name>
argocd app sync <app-name>
```

#### Running Web UI Locally

Similarly, users can also run the Web UI locally if they prefer to interact with Argo CD using this method. The Web UI can be started locally by running the following command:

```bash
# Start the local dashboard
argocd admin dashboard -n argocd
```

Argo CD Web UI will be available at `http://localhost:8080`

**Note**: The local dashboard uses the same authentication as the CLI. Make sure you're logged in with `argocd login --core` before starting the dashboard.

### Example Application Resource

Here's an example of creating an Application resource for Argo CD Core:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/my-app
    targetRevision: main
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Comparison: Full vs Core Installation

| Feature | Full Installation | Core Installation |
|---------|------------------|-------------------|
| API Server | ✅ Included | ❌ Not included |
| Web UI | ✅ Included | ⚠️ Local only |
| CLI | ✅ Full support | ⚠️ Requires `--core` flag |
| RBAC | ✅ Argo CD RBAC | ⚠️ Kubernetes RBAC only |
| OIDC Auth | ✅ Supported | ❌ Not supported |
| Notifications | ✅ Included | ❌ Not included |
| Application Controller | ✅ Included | ✅ Included |
| Repository Server | ✅ Included | ✅ Included |
| Redis | ✅ Included | ✅ Included |
| GitOps Functionality | ✅ Full | ✅ Full |

### When to Use Core vs Full Installation

**Use Full Installation when:**
- You need centralized API access
- Multiple users need UI access
- You want Argo CD RBAC features
- You need OIDC authentication
- You want notification capabilities
- You need ApplicationSet controller

**Use Core Installation when:**
- You want minimal footprint
- You prefer Kubernetes RBAC only
- You want to interact via Kubernetes API only
- You don't need centralized UI/API access
- You want to reduce attack surface
- You prefer GitOps-only workflow

## Uninstallation

### Basic Uninstallation

```bash
./argocd/install-argocd-minikube.sh uninstall
```

The script will:
1. Prompt for confirmation
2. Delete all Argo CD resources from the namespace
3. Remove CustomResourceDefinitions (CRDs)
4. Delete cluster-level resources
5. Remove the namespace

### Uninstallation Process

1. **Confirmation Prompt**
   - Asks for user confirmation before deletion
   - Shows what will be deleted

2. **Resource Deletion**
   - Deletes resources using the manifest (reverse apply)
   - Removes CustomResourceDefinitions
   - Deletes cluster roles and bindings

3. **Namespace Cleanup**
   - Force deletes pods with finalizers
   - Deletes the namespace
   - Handles stuck resources

4. **Manual Cleanup Instructions**
   - Provides commands for remaining resources if needed

### Uninstallation Output

```
🗑️  Argo CD Minikube Uninstallation
===================================

⚠ This will delete all Argo CD resources in the 'argocd' namespace
Are you sure you want to continue? (y/N): y

ℹ Deleting Argo CD resources...
ℹ Removing resources from manifest...
✓ Resources from manifest deleted
ℹ Removing CustomResourceDefinitions...
ℹ Removing cluster-level resources...
ℹ Deleting namespace 'argocd'...
✓ Namespace 'argocd' deleted

🗑️  Argo CD Uninstallation Complete!
==========================================

✓ Argo CD has been removed from your cluster
```

## Status Check

### Check Current Status

```bash
./argocd/install-argocd-minikube.sh status
```

### Status Output

The status command displays:
- Namespace information
- Deployment status
- StatefulSet status
- Pod status
- Service status
- Admin credentials (if available)

Example:
```
📊 Argo CD Status
================

ℹ Namespace: argocd

ℹ Deployments:
NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
argocd-applicationset-controller   1/1     1            1           5m
argocd-dex-server                  1/1     1            1           5m
...

ℹ Pods:
NAME                                                READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                     2/2     Running   0          5m
...

ℹ Admin Credentials:
  Username: admin
  Password: <password>
```

## Configuration

### Command-Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `install` | Install or update Argo CD (default) | `./script.sh install` |
| `uninstall` | Remove Argo CD completely | `./script.sh uninstall` |
| `status` | Show current status | `./script.sh status` |
| `-n, --namespace` | Custom namespace | `./script.sh -n my-ns` |
| `-h, --help` | Show help message | `./script.sh --help` |

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ARGOCD_NAMESPACE` | Kubernetes namespace | `argocd` |
| `MANIFEST_URL` | Argo CD manifest URL | Official GitHub manifest |

### Examples

```bash
# Install with custom namespace
ARGOCD_NAMESPACE=my-argocd ./argocd/install-argocd-minikube.sh

# Use custom manifest URL
MANIFEST_URL=https://example.com/custom-manifest.yaml ./argocd/install-argocd-minikube.sh

# Combine options
./argocd/install-argocd-minikube.sh install -n production
```

## Troubleshooting

### Common Issues

#### Port Conflicts / Duplicate Pods

**Symptoms:**
- Pods in `CrashLoopBackOff` state
- Error: "address already in use"

**Solution:**
```bash
# Restart all deployments
kubectl rollout restart deployment -n argocd

# Restart statefulsets
kubectl rollout restart statefulset -n argocd

# Or delete problematic pods (they will be recreated)
kubectl delete pod <pod-name> -n argocd
```

#### Pods in CrashLoopBackOff

**Diagnosis:**
```bash
# Check pod logs
kubectl logs <pod-name> -n argocd

# Check pod details
kubectl describe pod <pod-name> -n argocd

# Check events
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

**Common Causes:**
- Resource constraints (CPU/memory)
- Image pull errors
- Configuration issues
- Port conflicts

#### Admin Password Not Available

**Solution:**
```bash
# Wait and retry
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo

# Check if secret exists
kubectl get secret -n argocd | grep admin

# Check pod status (secret is created after first pod starts)
kubectl get pods -n argocd
```

#### Installation Stuck

**Diagnosis:**
```bash
# Check all resources
kubectl get all -n argocd

# Check deployment status
kubectl get deployments -n argocd

# Check events
kubectl get events -n argocd --sort-by='.lastTimestamp'

# Check pod logs
kubectl logs -n argocd --all-containers=true --tail=50
```

**Solution:**
- Increase minikube resources: `minikube config set memory 4096`
- Check network connectivity
- Verify minikube is running: `minikube status`

#### Minikube Not Starting

**Solution:**
```bash
# Check minikube status
minikube status

# Start minikube with more resources
minikube start --memory=4096 --cpus=2

# Check minikube logs
minikube logs
```

### Getting Help

```bash
# Show script help
./argocd/install-argocd-minikube.sh --help

# Check script version/logic
head -20 ./argocd/install-argocd-minikube.sh
```

## Architecture

### Architectural Overview

Argo CD follows a declarative, GitOps-based approach to continuous delivery. It operates as a Kubernetes controller that continuously monitors running applications and compares the current, live state against the desired target state (as specified in the Git repository).

### Argo CD Components

The installation includes the following core components:

#### API Server (argocd-server)

The API server is a gRPC/REST server which exposes the API consumed by the Web UI, CLI, and CI/CD systems. It has the following responsibilities:

- **Application Management and Status Reporting**
  - Manages Argo CD Application resources
  - Reports application health and sync status
  - Provides real-time status updates

- **Application Operations**
  - Invokes application operations (e.g. sync, rollback, user-defined actions)
  - Handles manual and automated sync operations
  - Manages application lifecycle events

- **Credential Management**
  - Repository and cluster credential management (stored as K8s secrets)
  - Secure storage and retrieval of Git repository credentials
  - Management of cluster connection credentials

- **Authentication and Authorization**
  - Authentication and auth delegation to external identity providers
  - RBAC enforcement
  - Integration with OIDC providers via Dex

- **Webhook Integration**
  - Listener/forwarder for Git webhook events
  - Handles incoming webhook notifications from Git providers
  - Triggers application updates based on repository changes

- **Web UI**
  - Serves the Argo CD web interface
  - Provides visual representation of application state
  - Enables user interaction with applications

#### Repository Server (argocd-repo-server)

The repository server is an internal service which maintains a local cache of the Git repository holding the application manifests. It is responsible for generating and returning the Kubernetes manifests when provided the following inputs:

- **Repository Management**
  - Clones and maintains local cache of Git repositories
  - Handles multiple repository types (Git, Helm, OCI)
  - Manages repository authentication

- **Manifest Generation**
  - Generates Kubernetes manifests from source repositories
  - Processes different manifest formats:
    - Plain YAML/JSON
    - Helm charts
    - Kustomize applications
    - Jsonnet
    - Ksonnet

- **Template Processing**
  - Template specific settings: parameters, helm values.yaml
  - Handles Helm value overrides
  - Processes Kustomize overlays
  - Applies application-specific configurations

- **Revision Management**
  - Handles repository URL, revision (commit, tag, branch), and application path
  - Supports multiple revision types (branches, tags, commits)
  - Manages application path filtering

#### Application Controller (argocd-application-controller)

The application controller is a Kubernetes controller which continuously monitors running applications and compares the current, live state against the desired target state (as specified in the repo). It detects OutOfSync application state and optionally takes corrective action.

**Key Responsibilities:**

- **Continuous Monitoring**
  - Monitors application state continuously
  - Compares live state against desired target state
  - Detects drift and synchronization issues

- **State Comparison**
  - Compares current, live state against desired target state (as specified in the repo)
  - Identifies differences between Git and cluster state
  - Reports sync status and health

- **Synchronization**
  - Syncs applications to target clusters
  - Applies changes from Git to Kubernetes clusters
  - Handles both manual and automated syncs

- **Lifecycle Management**
  - Manages application lifecycle
  - Invokes user-defined hooks for lifecycle events:
    - **PreSync**: Executed before sync operation
    - **Sync**: Main sync operation
    - **PostSync**: Executed after successful sync
  - Handles rollback operations

- **Multi-Cluster Support**
  - Manages applications across multiple Kubernetes clusters
  - Handles cluster credentials and connections
  - Supports both in-cluster and external cluster deployments

#### Supporting Components

4. **argocd-redis**
   - Caching layer for application state
   - Stores application metadata and status
   - Improves performance by reducing API calls
   - Used for state caching and temporary data storage

5. **argocd-dex-server** (optional)
   - OIDC provider for external authentication
   - Handles authentication delegation to external identity providers
   - Supports SSO integration (LDAP, SAML, OAuth2, etc.)
   - Manages user authentication tokens

6. **argocd-applicationset-controller** (optional)
   - Manages ApplicationSets for bulk application management
   - Automated application generation from templates
   - Supports multiple generators (Git directories, clusters, etc.)
   - Reduces manual application creation overhead

7. **argocd-notifications-controller** (optional)
   - Sends notifications for application events
   - Integrates with various notification systems (Slack, Teams, Email, etc.)
   - Configurable notification triggers and templates
   - Provides real-time alerts for application changes

### Resource Types

The installation creates:

- **Namespaces**: `argocd` (or custom)
- **Deployments**: Application components
- **StatefulSets**: Application controller
- **Services**: ClusterIP and LoadBalancer services
- **ConfigMaps**: Configuration data
- **Secrets**: TLS certificates, passwords
- **CustomResourceDefinitions**: Application, ApplicationSet, AppProject
- **ClusterRoles/ClusterRoleBindings**: Cluster-wide permissions
- **NetworkPolicies**: Network isolation rules

### Component Interaction Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      Argo CD Architecture                        │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│   Web UI     │         │     CLI      │         │   CI/CD      │
│   Browser    │─────────│   Commands   │─────────│   Systems    │
└──────┬───────┘         └──────┬───────┘         └──────┬───────┘
       │                        │                         │
       │                        │                         │
       └────────────────────────┼─────────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │   API Server            │
                    │  (argocd-server)        │
                    │                         │
                    │ • Application Management│
                    │ • Status Reporting       │
                    │ • Auth & RBAC           │
                    │ • Webhook Listener      │
                    └────────────┬────────────┘
                                 │
                    ┌────────────┼────────────┐
                    │            │            │
        ┌───────────▼──┐  ┌──────▼──────┐  ┌──────▼──────┐
        │ Repo Server  │  │ Application  │  │    Redis    │
        │              │  │ Controller  │  │             │
        │ • Git Cache  │  │             │  │ • Caching   │
        │ • Manifest   │  │ • Monitoring │  │ • State     │
        │   Generation │  │ • Sync       │  │             │
        │ • Templates  │  │ • Lifecycle  │  │             │
        └──────┬───────┘  └──────┬───────┘  └─────────────┘
               │                 │
               │                 │
    ┌──────────▼──────────┐  ┌───▼──────────────────┐
    │   Git Repository    │  │  Kubernetes Cluster   │
    │                     │  │  (Target Clusters)    │
    │ • Application Manifests│  │                     │
    │ • Helm Charts       │  │ • Deployed Apps      │
    │ • Kustomize         │  │ • Live State         │
    └─────────────────────┘  └──────────────────────┘
```

### Network Architecture

```
┌─────────────────────────────────────────┐
│         Minikube Cluster                  │
│                                           │
│  ┌─────────────────────────────────────┐ │
│  │      argocd Namespace                │ │
│  │                                      │ │
│  │  ┌──────────────┐                  │ │
│  │  │ argocd-server │                  │ │
│  │  │  (Port 443)   │                  │ │
│  │  └──────┬────────┘                  │ │
│  │         │                            │ │
│  │  ┌──────▼────────┐                  │ │
│  │  │ repo-server   │                  │ │
│  │  └───────────────┘                  │ │
│  │                                      │ │
│  │  ┌──────────────────┐              │ │
│  │  │ application-      │              │ │
│  │  │ controller        │              │ │
│  │  └───────────────────┘              │ │
│  │                                      │ │
│  │  ┌──────────────┐                  │ │
│  │  │ redis         │                  │ │
│  │  └──────────────┘                  │ │
│  └─────────────────────────────────────┘ │
│                                           │
└─────────────────────────────────────────┘
         │
         │ Port Forward (8080:443)
         ▼
    Local Browser
```

### Data Flow

1. **User/CI/CD initiates operation** → API Server receives request
2. **API Server validates** → Checks authentication, RBAC, and application state
3. **Repository Server fetches** → Clones Git repo and generates manifests
4. **Application Controller monitors** → Compares desired vs. live state
5. **Sync operation** → Controller applies changes to target cluster
6. **Status update** → Controller reports back to API Server
7. **User sees results** → Web UI/CLI displays updated status

## Script Reference

### Script Location

```
platform/
└── argocd/
    └── install-argocd-minikube.sh
```

### Script Functions

| Function | Purpose |
|----------|---------|
| `check_prerequisites()` | Verify minikube and kubectl are installed |
| `ensure_minikube_running()` | Start minikube if not running |
| `ensure_minikube_context()` | Set kubectl context to minikube |
| `wait_for_resource()` | Wait for resource to be ready |
| `cleanup_duplicate_pods()` | Clean up stuck or duplicate pods |
| `install_argocd()` | Main installation function |
| `uninstall_argocd()` | Main uninstallation function |
| `show_status()` | Display current status |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error (prerequisites, minikube, kubectl, etc.) |

### Logging

The script uses colored output:
- **Green (✓)**: Success
- **Red (✗)**: Error
- **Yellow (ℹ)**: Information
- **Blue (⚠)**: Warning

## Additional Resources

### Official Documentation

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Argo CD GitHub](https://github.com/argoproj/argo-cd)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)

### Related Commands

```bash
# Get Argo CD CLI
brew install argocd

# Login via CLI
argocd login localhost:8080 --insecure --username admin

# List applications
argocd app list

# Get application details
argocd app get <app-name>
```

### Next Steps

After installation:

1. **Change Admin Password**
   ```bash
   argocd account update-password
   ```

2. **Add Git Repository**
   - Use the UI or CLI to add repositories
   - Configure authentication

3. **Create Applications**
   - Define applications in Git
   - Sync applications to clusters

4. **Configure RBAC**
   - Set up user permissions
   - Configure project access

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2024 | Initial release with install/uninstall/status |

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review script output and error messages
3. Check Argo CD and Minikube documentation
4. Review Kubernetes events: `kubectl get events -n argocd`

---

**Note**: This is a non-HA installation suitable for development and testing. For production use, consider the HA installation or Argo CD Operator.

