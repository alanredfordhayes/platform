# Argo CD Quick Reference

Quick reference guide for common Argo CD operations in Minikube.

## Installation

```bash
# Basic installation
./argocd/install-argocd-minikube.sh

# Custom namespace
./argocd/install-argocd-minikube.sh -n my-namespace
```

## Uninstallation

```bash
./argocd/install-argocd-minikube.sh uninstall
```

## Status Check

```bash
./argocd/install-argocd-minikube.sh status
```

## Access UI

```bash
# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser
open https://localhost:8080
```

**Default Credentials:**
- Username: `admin`
- Password: (shown after installation)

## Get Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

## Common Commands

### Check Pods

```bash
kubectl get pods -n argocd
```

### Check Services

```bash
kubectl get svc -n argocd
```

### Check Deployments

```bash
kubectl get deployments -n argocd
```

### View Pod Logs

```bash
kubectl logs <pod-name> -n argocd
```

### Restart Components

```bash
# Restart all deployments
kubectl rollout restart deployment -n argocd

# Restart statefulsets
kubectl rollout restart statefulset -n argocd
```

### Check Events

```bash
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

## Troubleshooting

### Pods in CrashLoopBackOff

```bash
# Check logs
kubectl logs <pod-name> -n argocd

# Describe pod
kubectl describe pod <pod-name> -n argocd

# Restart
kubectl delete pod <pod-name> -n argocd
```

### Port Conflicts

```bash
# Restart all deployments
kubectl rollout restart deployment -n argocd
```

### Installation Stuck

```bash
# Check all resources
kubectl get all -n argocd

# Check events
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

## Argo CD CLI

### Install CLI

```bash
# macOS
brew install argocd
```

### Login

```bash
argocd login localhost:8080 --insecure --username admin
```

### List Applications

```bash
argocd app list
```

### Get Application

```bash
argocd app get <app-name>
```

### Sync Application

```bash
argocd app sync <app-name>
```

## Environment Variables

```bash
# Custom namespace
export ARGOCD_NAMESPACE=my-argocd

# Custom manifest URL
export MANIFEST_URL=https://example.com/manifest.yaml
```

## Script Options

| Command | Description |
|---------|-------------|
| `install` | Install/update Argo CD (default) |
| `uninstall` | Remove Argo CD |
| `status` | Show status |
| `-n, --namespace` | Custom namespace |
| `-h, --help` | Show help |

## Help

```bash
./argocd/install-argocd-minikube.sh --help
```

---

For detailed documentation, see [Argo CD Installation Guide](./argocd-installation.md).

