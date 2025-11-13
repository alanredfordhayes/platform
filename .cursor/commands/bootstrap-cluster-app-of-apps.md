# Bootstrap Cluster with App of Apps Pattern

Bootstrap your cluster using the App of Apps pattern with an `automation` parent app that manages an `argocd` child app.

## Overview

This command sets up:
- **Parent App**: `automation` - Manages all child applications
- **Child App**: `argocd` - Manages Argo CD installation itself

```
automation (Parent)
    └── argocd (Child)
            └── Manages Argo CD installation
```

### Important Security Note

**App of Apps is an admin-only tool**

Only admins should have push access to the parent Application's source repository. Always review pull requests, especially the project field in each Application.

## Quick Start

### Step 1: Create Directory Structure

```bash
mkdir -p argocd/app-of-apps/apps
```

### Step 2: Create Child App Definition

Create `argocd/app-of-apps/apps/argocd-child.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app.kubernetes.io/instance: automation
    app.kubernetes.io/name: argocd
spec:
  destination:
    namespace: argocd
    server: https://kubernetes.default.svc
  project: default
  source:
    repoURL: https://github.com/argoproj/argo-cd.git
    targetRevision: master
    path: manifests
    directory:
      include: "install.yaml"
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
      - RespectIgnoreDifferences=true
      - Replace=true
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
    # Ignore problematic annotations on CRDs that cause size limit issues
    - group: apiextensions.k8s.io
      kind: CustomResourceDefinition
      jsonPointers:
        - /metadata/annotations/kubectl.kubernetes.io~1last-applied-configuration
```

**Key Configuration:**
- `prune: false` and `selfHeal: false` - Prevents accidental deletion of Argo CD
- `ServerSideApply: true` - Required for managing Argo CD resources
- `Replace=true` - Uses replace instead of patch, prevents CRD annotation size limit errors
- `ignoreDifferences` - Prevents sync conflicts with Argo CD's internal secrets/configmaps and CRD annotations
- Label `app.kubernetes.io/instance: automation` - Links child to parent

### Step 3: Create Parent App Definition

Create `argocd/app-of-apps/apps/automation-parent.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: automation
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app.kubernetes.io/name: automation
spec:
  destination:
    namespace: argocd
    server: https://kubernetes.default.svc
  project: default
  source:
    repoURL: <your-git-repo-url>
    targetRevision: HEAD
    path: argocd/app-of-apps/apps
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - RespectIgnoreDifferences=true
  ignoreDifferences:
    - group: "*"
      kind: "Application"
      namespace: "*"
      jsonPointers:
        - /spec/syncPolicy/automated
        - /metadata/annotations/argocd.argoproj.io~1refresh
        - /operation
```

**Important**: Replace `<your-git-repo-url>` with your actual Git repository URL.

### Step 4: Commit and Push to Git

```bash
# Stage both files
git add argocd/app-of-apps/apps/argocd-child.yaml
git add argocd/app-of-apps/apps/automation-parent.yaml

# Commit
git commit -m "Add automation parent app and argocd child app"

# Push to repository
git push origin main
```

**Critical**: Files MUST be committed and pushed to Git before the parent app can discover them. Argo CD reads from Git, not local files.

### Step 5: Apply Parent Application

```bash
# Apply the parent app directly (it will discover child apps from Git)
# Note: The parent app is in the apps directory but is applied directly, not discovered
kubectl apply -f argocd/app-of-apps/apps/automation-parent.yaml
```

**Note**: The `automation-parent.yaml` file is in the `apps` directory for organization, but it's applied directly via `kubectl apply`. The parent app then reads from Git to discover child apps (like `argocd-child.yaml`) in that same directory.

### Step 6: Sync and Verify

```bash
# Refresh to pick up changes from Git
argocd app get automation --refresh

# Sync the parent app (will create child apps)
argocd app sync automation

# Verify both apps exist
argocd app list

# Check parent app status
argocd app get automation

# Check child app status
argocd app get argocd
```

## Expected Result

### File Structure

After completion, you should have:

```
argocd/app-of-apps/apps/
├── argocd-child.yaml        # Child app definition (discovered by parent)
└── automation-parent.yaml   # Parent app manifest (applied directly)
```

### Argo CD Applications

In Argo CD, you should see:
- `automation` app (parent) - Synced, Healthy
- `argocd` app (child) - Synced, Healthy, labeled with `app.kubernetes.io/instance: automation`

**Note**: The `automation-parent.yaml` is stored in the `apps` directory for organization, but it's applied directly to create the parent app. The parent app then reads from Git to discover and manage child apps in that directory.

## Adding More Child Apps

To add more child applications:

1. Create a new YAML file in `argocd/app-of-apps/apps/` (e.g., `my-app.yaml`)
2. Include the label: `app.kubernetes.io/instance: automation`
3. Commit and push to Git
4. The `automation` parent app will automatically discover and manage it

Example child app structure:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app.kubernetes.io/instance: automation
    app.kubernetes.io/name: my-app
spec:
  destination:
    namespace: my-app
    server: https://kubernetes.default.svc
  project: default
  source:
    repoURL: <your-app-repo-url>
    targetRevision: HEAD
    path: <path-to-manifests>
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Critical Lessons Learned

### 1. Git Repository is Required
- Parent app reads from Git, not local files
- Child app definitions MUST be committed and pushed before parent app can discover them
- Error "app path does not exist" means files aren't in Git yet

### 2. Don't Delete Argo CD App While Managing Argo CD
- If Argo CD app manages Argo CD itself, deleting it removes Argo CD
- Use `prune: false` and `selfHeal: false` for the Argo CD child app
- If Argo CD gets deleted, reinstall: `./argocd/install-argocd-minikube.sh install`

### 3. Server-Side Apply for Argo CD
- Use `ServerSideApply: true` when managing Argo CD itself
- Prevents issues with large resources and annotation limits
- Required for proper management of Argo CD's own resources

### 4. CRD Annotation Size Limit Error
**Error**: `CustomResourceDefinition "applicationsets.argoproj.io" is invalid: metadata.annotations: Too long: must have at most 262144 bytes`

**Solution**:
1. Add `Replace=true` to sync options (uses replace instead of patch)
2. Add `ignoreDifferences` for CRD annotations:
   ```yaml
   ignoreDifferences:
     - group: apiextensions.k8s.io
       kind: CustomResourceDefinition
       jsonPointers:
         - /metadata/annotations/kubectl.kubernetes.io~1last-applied-configuration
   ```
3. Manually remove problematic annotation if needed:
   ```bash
   kubectl annotate crd applicationsets.argoproj.io kubectl.kubernetes.io/last-applied-configuration- --overwrite
   ```

### 5. Refresh After Git Push
- After pushing to Git, refresh: `argocd app get automation --refresh`
- Argo CD caches Git repository state
- Wait a few seconds after pushing before refreshing

### 6. Label Child Applications
- Use `app.kubernetes.io/instance: automation` label on all child apps
- Enables filtering: `argocd app sync -l app.kubernetes.io/instance=automation`
- Makes parent-child relationship clear

## Troubleshooting

### Parent App Shows "Unknown" or "ComparisonError"

**Error**: "app path does not exist"

**Solution**:
```bash
# 1. Verify files are committed and pushed
git log --oneline argocd/app-of-apps/apps/

# 2. Verify path matches Git structure
kubectl get application automation -n argocd -o yaml | grep -A 3 "source:"

# 3. Refresh parent app
argocd app get automation --refresh

# 4. Check repository access
argocd repo list
```

### Child Apps Not Appearing

```bash
# Check parent app status
argocd app get automation

# Force refresh
argocd app get automation --refresh

# Sync parent app
argocd app sync automation

# Verify child app exists
argocd app get argocd
```

### Argo CD Deleted After Deleting Argo CD App

**Symptom**: Argo CD components are gone

**Solution**:
```bash
# Reinstall Argo CD
./argocd/install-argocd-minikube.sh install

# Recreate automation parent app
kubectl apply -f argocd/app-of-apps/apps/automation-parent.yaml

# Sync to recreate child apps
argocd app sync automation
```

**Prevention**: Always use `prune: false` for apps managing critical infrastructure.

### CRD Annotation Size Limit Error

**Error**: `CustomResourceDefinition "applicationsets.argoproj.io" is invalid: metadata.annotations: Too long: must have at most 262144 bytes`

**Solution**:
```bash
# 1. Remove problematic annotation
kubectl annotate crd applicationsets.argoproj.io kubectl.kubernetes.io/last-applied-configuration- --overwrite

# 2. Update child app manifest to include Replace=true and ignoreDifferences
# (See "CRD Annotation Size Limit Error" in Lessons Learned)

# 3. Commit and push changes
git add argocd/app-of-apps/apps/argocd-child.yaml
git commit -m "Fix CRD annotation size error"
git push

# 4. Refresh and sync
argocd app get automation --refresh
argocd app sync argocd --server-side
```

**Prevention**: Always use `ServerSideApply: true` and `Replace=true` for apps managing CRDs.

## Verification Commands

```bash
# List all applications
argocd app list

# Check parent app
argocd app get automation

# Check child app
argocd app get argocd

# Verify labels
kubectl get application argocd -n argocd -o jsonpath='{.metadata.labels}'

# Sync all automation children
argocd app sync -l app.kubernetes.io/instance=automation
```

## Best Practices

1. **Commit Before Creating Parent**: Always commit and push child app definitions before creating parent app
2. **Use Specific Revisions**: Use Git commit SHAs instead of HEAD for reproducibility
3. **Label Consistently**: Use `app.kubernetes.io/instance: automation` on all child apps
4. **Use Finalizers**: Always include finalizers for proper cleanup
5. **Protect Critical Apps**: Use `prune: false` for apps managing critical infrastructure
6. **Refresh After Changes**: Always refresh parent app after pushing to Git
7. **Monitor Status**: Regularly check application status with `argocd app list`

## Additional Resources

- [Argo CD Application CRD Documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/application.yaml)
- [Argo CD Sync Policies](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-policies/)
- [Server-Side Apply](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/#server-side-apply)
