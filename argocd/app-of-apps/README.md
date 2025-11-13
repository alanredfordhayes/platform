# App of Apps Pattern - Quick Start

This directory contains templates and manifests for bootstrapping your cluster using the App of Apps pattern.

**Important**: This setup does NOT install example applications. You must provide your own Git repository with your application definitions.

## Quick Start

### Create Parent App via CLI

Replace the placeholders with your own values:

```bash
argocd app create <parent-app-name> \
    --dest-namespace argocd \
    --dest-server https://kubernetes.default.svc \
    --repo <your-git-repo-url> \
    --path <path-to-apps-directory> \
    --sync-policy automated \
    --self-heal \
    --auto-prune

# Sync the parent application
argocd app sync <parent-app-name>
```

### Create Parent App via Kubernetes Manifest

1. Create a manifest file (see `automation-parent.yaml` as a template)
2. Update it with your repository URL and path
3. Apply it:

```bash
kubectl apply -f <your-parent-app-manifest>.yaml
```

## What Happens Next

1. The parent app will be created and synced
2. Argo CD will discover child applications defined in your repository's apps directory
3. Child apps will initially show as "OutOfSync"
4. Sync the child apps using one of the methods below

## Syncing Child Applications

### Via CLI

```bash
# Sync all apps with the label (replace with your parent app name)
argocd app sync -l app.kubernetes.io/instance=<parent-app-name>

# Or sync individual apps
argocd app sync <child-app-name>
```

### Via UI

1. Port forward to access UI:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```

2. Open https://localhost:8080

3. Filter by label: `app.kubernetes.io/instance=<parent-app-name>`

4. Select out-of-sync apps and click "Sync"

## Customizing for Your Use Case

1. **Update the repository URL** in your parent app manifest to point to your Git repository
2. **Modify the path** to point to your apps directory
3. **Set a specific revision** (commit SHA) instead of `HEAD` for reproducibility
4. **Adjust sync policies** based on your needs
5. **Create child application manifests** in your Git repository

## Files

- `automation-parent.yaml` - Example parent application manifest (customize for your use case)
- `argocd-child.yaml` - Example child application for Argo CD management
- `templates/` - Helm templates (if using Helm)

## Security Reminder

⚠️ **App of Apps is an admin-only tool**

Only admins should have push access to the parent Application's source repository. Always review pull requests, especially the project field in each Application.

## Next Steps

- Review the [complete guide](../../.cursor/commands/bootstrap-cluster-app-of-apps.md)
- Set up your own Git repository with application definitions
- Customize the manifests for your repository
- Set up proper RBAC and projects
- Consider using specific Git commit SHAs instead of HEAD

## Important Notes

- **Do NOT use example repositories** (`argoproj/argocd-example-apps`) in production
- Always use your own Git repository with your application definitions
- Use specific commit SHAs for reproducibility
- Review and customize all manifests before applying
