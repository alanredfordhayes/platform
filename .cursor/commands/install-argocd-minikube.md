# Install Argo CD in Minikube (Non-HA)

Install Argo CD into a minikube cluster using the standard non-HA installation manifest. This is suitable for evaluation, demonstrations, and testing purposes.

## Quick Start (Fully Automated)

The script is **idempotent** - it can be run multiple times safely and will handle existing installations gracefully.

### Install Argo CD
```bash
./argocd/install-argocd-minikube.sh
# or explicitly
./argocd/install-argocd-minikube.sh install
```

### Uninstall Argo CD
```bash
./argocd/install-argocd-minikube.sh uninstall
```

### Check Status
```bash
./argocd/install-argocd-minikube.sh status
```

### Custom Namespace
```bash
./argocd/install-argocd-minikube.sh -n my-namespace
```

### Help
```bash
./argocd/install-argocd-minikube.sh --help
```

## Script Features

### Installation Features

The installation script (`install-argocd-minikube.sh install`) will:
- Check prerequisites (minikube, kubectl)
- Check and start minikube if needed
- Verify kubectl context is set to minikube
- Detect and handle existing Argo CD installations (idempotent)
- Clean up duplicate or stuck pods automatically
- Create the argocd namespace if needed
- Apply the installation manifest from the official Argo CD repository
- Wait for deployments and statefulsets individually with proper timeouts
- Detect and report pod issues (CrashLoopBackOff, port conflicts, etc.)
- Retrieve and display the admin password (with retry logic)
- Show comprehensive status of all pods and services
- Provide helpful diagnostic commands

### Uninstallation Features

The uninstallation script (`install-argocd-minikube.sh uninstall`) will:
- Prompt for confirmation before deletion
- Remove all Argo CD resources from the namespace
- Delete CustomResourceDefinitions (CRDs)
- Remove cluster-level resources (ClusterRoles, ClusterRoleBindings)
- Delete the namespace (with proper cleanup)
- Provide instructions for manual cleanup if needed

### Status Features

The status command (`install-argocd-minikube.sh status`) will:
- Display current Argo CD installation status
- Show pod readiness and health
- List all Argo CD services
- Display admin password retrieval instructions

## Prerequisites

- **Minikube**: Must be installed (will be started automatically if not running)
- **kubectl**: Must be installed and configured
- **kubectl context**: Should be set to minikube (script will attempt to switch if needed)

The script will verify these prerequisites and provide helpful error messages if they're missing.

## Manual Installation Steps

1. **Verify minikube is running:**
   ```bash
   minikube status
   kubectl config current-context
   ```
   If minikube is not running, start it with: `minikube start`

2. **Create argocd namespace:**
   ```bash
   kubectl create namespace argocd
   ```

3. **Download and apply the Argo CD installation manifest:**
   ```bash
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/install.yaml
   ```

4. **Wait for all Argo CD pods to be ready:**
   ```bash
   kubectl wait --for=condition=available --timeout=300s --all deployments -n argocd
   ```
   Or check pod status:
   ```bash
   kubectl get pods -n argocd -w
   ```
   Wait until all pods show `Running` status (Ctrl+C to exit watch mode).

5. **Get the initial admin password:**
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
   ```
   Save this password - you'll need it to login to Argo CD.

6. **Set up port-forwarding to access Argo CD UI:**
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```
   The Argo CD UI will be available at: https://localhost:8080
   - Username: `admin`
   - Password: (from step 5)

7. **Optional: Install Argo CD CLI for command-line access:**
   ```bash
   # macOS
   brew install argocd
   
   # Or download from: https://github.com/argoproj/argo-cd/releases/latest
   ```

8. **Optional: Login via CLI:**
   ```bash
   argocd login localhost:8080 --insecure --username admin --password <password-from-step-5>
   ```

## Verification

Check that all Argo CD components are running:
```bash
kubectl get pods -n argocd
kubectl get svc -n argocd
```

Expected services:
- `argocd-server` - Main API server and UI
- `argocd-repo-server` - Git repository access
- `argocd-application-controller` - Application controller (StatefulSet)
- `argocd-redis` - Redis cache
- `argocd-dex-server` - SSO/OIDC server (if enabled)
- `argocd-applicationset-controller` - ApplicationSet controller (if enabled)
- `argocd-notifications-controller` - Notifications controller (if enabled)
- `argocd-server-metrics` - Server metrics endpoint
- `argocd-metrics` - General metrics endpoint

## Troubleshooting

### Port Conflicts / Duplicate Pods

If you see errors like "address already in use" or duplicate pods:

```bash
# Restart all deployments
kubectl rollout restart deployment -n argocd

# Restart statefulsets
kubectl rollout restart statefulset -n argocd

# Or delete specific problematic pods (they will be recreated)
kubectl delete pod <pod-name> -n argocd
```

**Note**: The installation script automatically detects and handles duplicate pods by restarting deployments/statefulsets.

### Pods in CrashLoopBackOff

Check pod logs to diagnose:

```bash
kubectl logs <pod-name> -n argocd
kubectl describe pod <pod-name> -n argocd
```

Common causes:
- Resource constraints (CPU/memory)
- Configuration errors
- Missing dependencies
- Port conflicts

### Admin Password Not Available

The password secret is created after the first pod starts. If it's not ready:

```bash
# Wait a bit and try again
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo

# Or check if the secret exists
kubectl get secret -n argocd | grep admin

# Check if the secret is being created
kubectl get events -n argocd --sort-by='.lastTimestamp' | grep secret
```

**Note**: The installation script includes retry logic to wait for the password secret.

### Installation Stuck

If the installation seems stuck:

```bash
# Check all resources
kubectl get all -n argocd

# Check events for errors
kubectl get events -n argocd --sort-by='.lastTimestamp'

# Check deployment status
kubectl get deployments -n argocd
kubectl get statefulsets -n argocd

# Check pod status
kubectl get pods -n argocd
```

## Managing Argo CD with Argo CD (App of Apps Pattern)

If you plan to manage Argo CD itself using Argo CD (App of Apps pattern), be aware of potential sync errors:

### CRD Annotation Size Limit Error

**Error**: `CustomResourceDefinition "applicationsets.argoproj.io" is invalid: metadata.annotations: Too long: must have at most 262144 bytes`

This error occurs when Argo CD tries to manage itself and CRDs have large annotations from client-side apply operations.

**Solution** (when using App of Apps pattern):

1. **Use Server-Side Apply and Replace**:
   ```yaml
   syncOptions:
     - ServerSideApply=true
     - Replace=true
   ```

2. **Ignore CRD annotations**:
   ```yaml
   ignoreDifferences:
     - group: apiextensions.k8s.io
       kind: CustomResourceDefinition
       jsonPointers:
         - /metadata/annotations/kubectl.kubernetes.io~1last-applied-configuration
   ```

3. **Manually clean up if needed**:
   ```bash
   kubectl annotate crd applicationsets.argoproj.io kubectl.kubernetes.io/last-applied-configuration- --overwrite
   ```

**Note**: This error is specific to managing Argo CD with Argo CD. The initial installation script (`install-argocd-minikube.sh`) does not encounter this issue.

### Application Shows "OutOfSync"

When Argo CD manages itself, it's normal to see some resources as "OutOfSync":

**Common OutOfSync Resources**:
- Secrets (especially `argocd-secret` and `argocd-initial-admin-secret`)
- ConfigMaps (updated by Argo CD internally)

**Solution**:
```yaml
ignoreDifferences:
  # Ignore changes to secrets that Argo CD manages internally
  - group: ""
    kind: Secret
    name: argocd-secret
    jsonPointers:
      - /data
  - group: ""
    kind: Secret
    name: argocd-initial-admin-secret
    jsonPointers:
      - /data
  # Ignore configmaps that are updated by Argo CD
  - group: ""
    kind: ConfigMap
    jsonPointers:
      - /data
```

**Important**: Set `prune: false` and `selfHeal: false` to prevent accidental deletion of Argo CD when managing itself.

For complete App of Apps setup instructions, see: `/bootstrap-cluster-app-of-apps`

## Notes

- This is a **non-HA installation** - not recommended for production use
- The installation uses cluster-admin access
- Argo CD can deploy to the same cluster (`kubernetes.default.svc`) and external clusters with credentials
- The initial admin password is stored in the `argocd-initial-admin-secret` secret
- **The script is idempotent** - you can run it multiple times safely; it will detect and update existing installations
- The script can be run independently without requiring external dependencies beyond minikube and kubectl
- For production, consider using the HA installation or Argo CD Operator
- Uninstallation requires confirmation and will remove all Argo CD resources
- When managing Argo CD with Argo CD itself, use `ServerSideApply: true` and `Replace=true` to avoid CRD annotation size limit errors

