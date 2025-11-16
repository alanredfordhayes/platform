# Platform Engineering Demo - Agent Instructions

## Project Overview

This is a GitOps-managed Kubernetes platform repository using Argo CD for continuous delivery. All infrastructure is managed as code through Git, following strict GitOps principles. The platform demonstrates modern cloud-native technologies including identity management, secrets management, CI/CD, observability, and developer portals.

## Core Principles

### GitOps First
- **ALL changes must go through Git** - no direct kubectl modifications
- **NEVER use `kubectl patch`, `kubectl set`, `kubectl edit`** for configuration changes
- All infrastructure changes must be committed and pushed to Git
- Argo CD manages all deployments from Git state
- If it's not in Git, it doesn't exist

### Version Management
- **Always use Context7 MCP** to determine latest compatible versions
- Check versions for: Helm charts, container images, application versions, plugins
- Update `targetRevision` in Argo CD Applications with actual version numbers (not `latest`)
- Document version decisions in commit messages

### Secrets Management
- **Never commit secrets** to Git
- Use External Secrets Operator to pull secrets from Vault
- Reference secrets via `env://SECRET_NAME` pattern in Helm values
- Store all secrets in Vault, not in Kubernetes Secrets directly
- Use `ignoreDifferences` for Secrets in Argo CD Applications to prevent drift

## Repository Structure

```
platform/
├── argocd/
│   ├── app-of-apps/
│   │   ├── apps/                    # Argo CD Application manifests
│   │   │   ├── automation/         # Automation category apps
│   │   │   ├── security/           # Security category apps
│   │   │   ├── observability/      # Observability category apps
│   │   │   ├── network/            # Network category apps
│   │   │   ├── platform/           # Platform infrastructure apps
│   │   │   └── *-parent.yaml       # Parent applications
│   │   ├── projects/               # Argo CD Projects
│   │   ├── values/                 # Helm values files
│   │   ├── configmaps/             # ConfigMap definitions
│   │   └── templates/              # Helm templates (if needed)
│   └── workflows/                  # Argo Workflow templates
├── vault/                          # Vault configuration
└── PLAN.md                         # Implementation plan
```

## File Organization Patterns

### Application Manifests
- **Location**: `argocd/app-of-apps/apps/{category}/`
- **Naming**: `{component-name}.yaml` (e.g., `vault.yaml`, `authentik.yaml`)
- **Parent apps**: `{category}-parent.yaml` in `apps/` directory
- **Structure**: Each app should be in its category directory

### Helm Values Files
- **Location**: `argocd/app-of-apps/values/`
- **Naming**: `{component-name}-values.yaml`
- **Reference**: Use `$values/{component-name}-values.yaml` in Argo CD Applications
- **Security**: Never include secrets directly - use `env://` references

### Argo CD Projects
- **Location**: `argocd/app-of-apps/projects/`
- **Naming**: `{category}-project.yaml`
- **Structure**: One project per category (automation, security, observability, network, platform)

### ConfigMaps
- **Location**: `argocd/app-of-apps/configmaps/`
- **Purpose**: Non-sensitive configuration data
- **Management**: Managed via Argo CD Application in same directory

## Argo CD Application Structure

### Standard Application Template

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {component-name}
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app.kubernetes.io/instance: {category}
    app.kubernetes.io/name: {component-name}
spec:
  destination:
    namespace: {component-namespace}
    server: https://kubernetes.default.svc
  project: {category}
  source:
    repoURL: {helm-repo-url}
    chart: {chart-name}
    targetRevision: {version}  # Use Context7 MCP to get latest
    helm:
      valueFiles:
        - $values/{component-name}-values.yaml
      values: |
        # Inline values override valueFiles
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
      - RespectIgnoreDifferences=true
  ignoreDifferences:
    - group: ""
      kind: Secret
      namespace: {component-namespace}
      jsonPointers:
        - /data
    - group: ""
      kind: ConfigMap
      namespace: {component-namespace}
      jsonPointers:
        - /data
    - group: ""
      kind: PersistentVolumeClaim
      namespace: {component-namespace}
      jsonPointers:
        - /status
```

### Key Fields

- **finalizers**: Always include `resources-finalizer.argocd.argoproj.io` for proper cleanup
- **labels**: Use `app.kubernetes.io/instance: {category}` and `app.kubernetes.io/name: {component-name}`
- **project**: Must match an existing Argo CD Project
- **targetRevision**: Use specific version numbers, not `latest` or `HEAD` (except for Git sources)
- **syncPolicy**: Parent apps use automated sync; child apps may vary
- **ignoreDifferences**: Always include for Secrets, ConfigMaps, and PVCs to prevent drift

## Helm Values Patterns

### Secret References

```yaml
# In values files, use env:// pattern
password: "env://SECRET_NAME"

# In Argo CD Application, provide environment variables
env:
  - name: SECRET_NAME
    valueFrom:
      secretKeyRef:
        name: {secret-name}
        key: {key-name}
```

### External Secrets Integration

```yaml
# ExternalSecret pulls from Vault
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {component}-secret
  namespace: {namespace}
spec:
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: {component}-secret
    creationPolicy: Owner
  data:
    - secretKey: {key-name}
      remoteRef:
        key: platform/{component}/{secret-path}
```

## Deployment Dependencies

### Critical Order

1. **Phase 0**: Bootstrap Argo CD (manual installation)
2. **Phase 1**: Vault (secrets management)
3. **Phase 1.5**: PostgreSQL Operator → PostgreSQL Cluster → Redis (shared infrastructure)
4. **Phase 2**: External Secrets Operator (depends on Vault)
5. **Phase 3**: Authentik (depends on PostgreSQL)
6. **Phase 4**: OAuth2 Proxy (depends on Authentik)
7. **Phase 5**: Backstage (depends on Authentik, PostgreSQL, OAuth2 Proxy)
8. **Phase 6**: Other automation tools (Argo Workflows, Harbor, Crossplane)

### Dependency Rules

- **PostgreSQL MUST be deployed before Authentik and Backstage**
- **Authentik MUST be deployed before Backstage** (OAuth2 Proxy requirement)
- **Vault MUST be initialized and unsealed before External Secrets**
- **External Secrets MUST be deployed before components that need secrets**

## Version Management Workflow

### Using Context7 MCP

1. **Resolve library/package name** to Context7-compatible ID
2. **Retrieve latest version** information
3. **Update `targetRevision`** in Argo CD Application
4. **Update documentation** in PLAN.md if needed
5. **Commit with message**: `chore: update {component} to version {version}`

### Version Update Example

```bash
# 1. Use Context7 MCP to get latest version
# 2. Update argocd/app-of-apps/apps/security/vault.yaml
targetRevision: 0.31.0  # Latest version (Vault 1.20.4) - Updated via Context7 MCP

# 3. Commit
git add argocd/app-of-apps/apps/security/vault.yaml
git commit -m "chore: update Vault to version 0.31.0"
git push origin main
```

## Configuration Management

### Non-Sensitive Configuration

- **Use ConfigMaps** for non-sensitive configuration
- **Location**: `argocd/app-of-apps/configmaps/`
- **Managed via**: Argo CD Application in same directory
- **Example**: `platform-config.yaml` for platform-wide settings

### Sensitive Configuration

- **Use External Secrets** pulling from Vault
- **Location**: `argocd/app-of-apps/apps/{category}/{component}-external-secrets.yaml`
- **Managed via**: Separate Argo CD Application or included in component app
- **Pattern**: Store in Vault at `platform/{component}/{secret-name}`

### Environment Variables

- **Placeholders**: Use `${VARIABLE_NAME}` in templates
- **Replacement**: Document in README files or use ConfigMaps
- **Secrets**: Always use External Secrets, never hardcode

## Naming Conventions

### Files
- **Applications**: `{component-name}.yaml` (lowercase, kebab-case)
- **Parent apps**: `{category}-parent.yaml`
- **Values files**: `{component-name}-values.yaml`
- **Projects**: `{category}-project.yaml`
- **External Secrets**: `{component}-external-secrets.yaml`

### Kubernetes Resources
- **Namespaces**: Match component name (e.g., `vault`, `authentik`, `backstage`)
- **Labels**: Use `app.kubernetes.io/instance: {category}` and `app.kubernetes.io/name: {component-name}`
- **Secrets**: `{component}-{purpose}-secret` (e.g., `authentik-secret-key`)

### Git Commits
- **Format**: `{type}: {description}`
- **Types**: `feat`, `fix`, `chore`, `docs`, `refactor`
- **Examples**:
  - `feat: add Harbor container registry`
  - `fix: update Vault configuration for minikube`
  - `chore: update Authentik to version 2024.10.0`

## Workflow Patterns

### Argo Workflows

- **Location**: `argocd/workflows/`
- **Naming**: `{purpose}-workflow.yaml`
- **Structure**: Use WorkflowTemplate for reusability
- **Parameters**: Always include required parameters, avoid defaults for critical values

### Build Workflow Pattern

1. **Checkout** source code
2. **Build** container image
3. **Push** to Harbor registry
4. **Update** platform repository with new image tag
5. **Commit and push** changes (triggers Argo CD sync)

## Troubleshooting Guidelines

### When Components Fail

1. **Check Argo CD Application status**: `kubectl get application {name} -n argocd`
2. **Review sync status**: Look for `OutOfSync` or `Degraded` states
3. **Check pod logs**: `kubectl logs -n {namespace} {pod-name}`
4. **Verify dependencies**: Ensure all dependencies are deployed and ready
5. **Check secrets**: Verify External Secrets are synced: `kubectl get externalsecret -n {namespace}`
6. **Review Git state**: Ensure changes are committed and pushed

### Common Issues

- **OutOfSync**: Usually expected for Secrets/ConfigMaps - check `ignoreDifferences`
- **Degraded**: Check pod status and logs
- **Pending**: Check resource constraints or dependencies
- **Secret not found**: Verify External Secret is synced and Vault has the secret

## Code Style Guidelines

### YAML Formatting

- **Indentation**: 2 spaces (never tabs)
- **Quotes**: Use quotes for strings that might be interpreted as numbers/booleans
- **Comments**: Use `#` for inline documentation
- **Line length**: Keep under 120 characters when possible

### Documentation

- **README files**: Include in each major directory
- **Comments**: Document non-obvious configuration choices
- **PLAN.md**: Keep updated with implementation details
- **Commit messages**: Be descriptive and reference issues if applicable

## Security Best Practices

### Secrets

- ✅ Store all secrets in Vault
- ✅ Use External Secrets Operator for Kubernetes integration
- ✅ Reference secrets via `env://` in Helm values
- ✅ Never commit secrets to Git
- ✅ Rotate secrets regularly

### Access Control

- ✅ Use Argo CD Projects to limit access
- ✅ Implement RBAC for Kubernetes resources
- ✅ Use Authentik for application authentication
- ✅ Use OAuth2 Proxy for protected services

### Network Security

- ✅ Use TLS for all external-facing services
- ✅ Configure ingress with proper annotations
- ✅ Use cert-manager for certificate management
- ✅ Implement network policies where appropriate

## Testing and Validation

### Before Committing

1. **Validate YAML**: `yamllint` or `kubectl apply --dry-run=client`
2. **Check Argo CD syntax**: Ensure Application manifest is valid
3. **Verify dependencies**: Ensure all referenced resources exist
4. **Test locally**: Use `kubectl apply --dry-run=server` if possible

### After Deployment

1. **Verify Argo CD sync**: `kubectl get application {name} -n argocd`
2. **Check pod status**: `kubectl get pods -n {namespace}`
3. **Verify services**: `kubectl get svc -n {namespace}`
4. **Test functionality**: Access services and verify behavior

## Common Tasks

### Adding a New Component

1. **Create Argo CD Application** in appropriate category directory
2. **Create Helm values file** in `values/` directory
3. **Create External Secrets** if needed
4. **Update parent application** to include new component
5. **Document in PLAN.md**
6. **Commit and push**

### Updating a Component Version

1. **Use Context7 MCP** to get latest version
2. **Update `targetRevision`** in Argo CD Application
3. **Update values file** if needed
4. **Test compatibility** with dependencies
5. **Commit with version update message**

### Troubleshooting a Component

1. **Check Git state**: Ensure latest changes are committed
2. **Verify Argo CD sync**: Check application status
3. **Review logs**: Check component and Argo CD logs
4. **Verify secrets**: Ensure External Secrets are synced
5. **Check dependencies**: Ensure all dependencies are ready
6. **Update configuration**: Make changes in Git, commit, push, sync

## Important Reminders

- **GitOps is the law**: All changes go through Git
- **Context7 for versions**: Always check latest versions
- **Vault for secrets**: Never commit secrets
- **Argo CD manages**: Let Argo CD handle deployments
- **Document changes**: Update PLAN.md and README files
- **Test before commit**: Validate YAML and dependencies

## Additional Resources

- **PLAN.md**: Comprehensive implementation plan
- **README.md**: Quick start guide
- **Values README**: `argocd/app-of-apps/values/README.md`
- **ConfigMaps README**: `argocd/app-of-apps/configmaps/README.md`
- **Argo CD Docs**: https://argo-cd.readthedocs.io/
- **External Secrets Docs**: https://external-secrets.io/

