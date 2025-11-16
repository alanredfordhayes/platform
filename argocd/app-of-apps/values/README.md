# Values Files Directory

This directory contains Helm values files referenced by Argo CD Applications. These files should be stored in your Git repository and referenced via the `valueFiles` parameter in Argo CD Application manifests.

## Structure

```
values/
├── README.md                    # This file
├── argocd-values.yaml          # Argo CD configuration
├── vault-values.yaml           # Vault configuration
├── external-secrets-values.yaml # External Secrets Operator configuration
├── argo-workflows-values.yaml  # Argo Workflows configuration
├── crossplane-values.yaml      # Crossplane configuration
├── harbor-values.yaml          # Harbor configuration
├── alloy-values.yaml           # Grafana Alloy configuration
├── authentik-values.yaml       # Authentik configuration
└── redis-values.yaml           # Redis configuration
```

## Usage

Values files are referenced in Argo CD Application manifests using the `$values/` prefix:

```yaml
source:
  helm:
    valueFiles:
      - $values/vault-values.yaml
```

## Git Repository Location

These files should be committed to your Git repository. Argo CD will read them from the repository when syncing applications.

## Security Considerations

- **Never commit secrets** directly in values files
- Use External Secrets Operator for sensitive values
- Reference secrets via environment variables: `password: "env://SECRET_NAME"`
- Use Vault for secret management

## Template Files

The files in this directory are templates. Replace placeholders with actual values:

- `<latest-version>` - Use Context7 MCP to get latest version
- `<cluster-name>` - Your Kubernetes cluster name
- `<domain>` - Your domain name
- `<email>` - Your email address

## Example

See individual values files for complete examples. Each file includes:

- Required configuration
- Optional settings
- Security best practices
- Integration points

