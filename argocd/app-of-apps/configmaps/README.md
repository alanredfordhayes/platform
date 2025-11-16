# Platform ConfigMap

This ConfigMap contains all non-sensitive, environment-specific configuration values for the platform.

## Usage

### In Deployments

Reference the ConfigMap in your deployments:

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        envFrom:
        - configMapRef:
            name: platform-config
```

### In Helm Values

Reference ConfigMap values in Helm charts:

```yaml
env:
  - name: BACKSTAGE_BASE_URL
    valueFrom:
      configMapKeyRef:
        name: platform-config
        key: BACKSTAGE_BASE_URL
```

### In Argo CD Applications

The ConfigMap should be synced by Argo CD along with your applications. Ensure it's included in your sync scope.

## Environment-Specific ConfigMaps

For multiple environments, create separate ConfigMaps:

- `platform-config-dev` - Development environment
- `platform-config-staging` - Staging environment  
- `platform-config-prod` - Production environment

Or use Kustomize overlays to manage environment-specific values.

## Updating Values

1. Edit the ConfigMap YAML file
2. Commit and push to Git
3. Argo CD will automatically sync the changes
4. Pods will need to be restarted to pick up new values (or use a rolling update)

## Security

- **Never include sensitive values** in this ConfigMap
- Use External Secrets Operator for passwords, tokens, and keys
- This ConfigMap is safe to commit to Git

