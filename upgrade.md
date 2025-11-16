# Authentik Upgrade Guide

This guide provides instructions for upgrading authentik to the latest version, whether a new major release or a patch update.

## Important Considerations

### ⚠️ DANGER: No Downgrade Support

**authentik does not support downgrading.** Make sure to back up your database in case you need to revert an upgrade.

### Preview Release Notes

Be sure to carefully read the [Release Notes](https://goauthentik.io/docs/releases/) for the specific version to which you plan to upgrade. The release might have special requirements or actions or contain breaking changes.

### Database Backup

Before upgrading, make a backup of your PostgreSQL database. You can create a backup by dumping your existing database. For detailed instructions, refer to the relevant guide for your deployment method:

- **Docker Compose**: See [Docker Compose backup documentation](https://goauthentik.io/docs/installation/docker-compose/#backup)
- **Kubernetes**: See [Kubernetes backup documentation](https://goauthentik.io/docs/installation/kubernetes/#backup)

### Upgrade Sequence

**Upgrades must follow the sequence of major releases; do not skip directly from an older major version to the most recent version.**

Always upgrade to the latest minor version (.x) within each major.minor version before upgrading to the next major version. For example, if you're currently running 2025.2.1, upgrade in the following order:

1. Upgrade to the latest 2025.2.x
2. Then to the latest 2025.4.x
3. Finally to the latest 2025.6.x

### Outposts Version Matching

**The version of the authentik server and all authentik outposts must match.** Ensure that all outposts are upgraded at the same time as the core authentik instance.

## Upgrade Authentik

### Docker Compose

In your terminal, navigate to your installation directory and follow these steps:

#### 1. Retrieve Latest docker-compose.yml File

Download the docker-compose.yml file using one of the following methods:

```bash
# Using wget
wget -O docker-compose.yml https://docs.goauthentik.io/docker-compose.yml

# Using curl
curl -O https://docs.goauthentik.io/docker-compose.yml
```

#### 2. Run Upgrade Commands

```bash
# Pull the latest images
docker compose pull

# Start the upgraded containers
docker compose up -d
```

#### 3. Upgrade Any Outposts

Be sure to also upgrade any outposts when you upgrade your authentik instance. Outposts should be upgraded to match the server version.

### Kubernetes (Helm Chart)

For Kubernetes deployments using Helm, follow these steps:

#### 1. Review Release Notes

Check the [Authentik Release Notes](https://goauthentik.io/docs/releases/) for the target version to identify any breaking changes or special upgrade requirements.

#### 2. Backup Database

Create a backup of your PostgreSQL database before upgrading:

```bash
# If using Zalando Postgres Operator
kubectl exec -n platform platform-postgres-0 -- pg_dump -U zalando authentik > authentik-backup-$(date +%Y%m%d-%H%M%S).sql

# Or use your preferred backup method
```

#### 3. Update Helm Repository

```bash
helm repo update authentik
```

#### 4. Upgrade Authentik

```bash
# Upgrade to specific version
helm upgrade authentik authentik/authentik \
  --namespace authentik \
  --version <target-version> \
  -f values.yaml

# Or upgrade to latest version
helm upgrade authentik authentik/authentik \
  --namespace authentik \
  -f values.yaml
```

#### 5. Verify Upgrade

Check that the pods are running with the new version:

```bash
# Check pod status
kubectl get pods -n authentik

# Check image versions
kubectl get pods -n authentik -o jsonpath='{.items[*].spec.containers[*].image}'
```

#### 6. Upgrade Outposts

Upgrade all outposts to match the server version. Outposts can be upgraded by:

- Updating the outpost deployment manifests
- Using the Authentik UI to trigger outpost updates
- Applying updated outpost configurations via GitOps

### GitOps Deployment (Argo CD)

For deployments managed via Argo CD:

#### 1. Update Application Manifest

Update the `targetRevision` in your Authentik Argo CD Application manifest:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: authentik
  namespace: argocd
spec:
  source:
    repoURL: https://charts.goauthentik.io
    chart: authentik
    targetRevision: <target-version>  # Update this
    helm:
      valueFiles:
        - $values/authentik/helm-values/authentik-values.yaml
```

#### 2. Sync Application

Argo CD will automatically detect the change and sync the application:

```bash
# Manual sync
argocd app sync authentik

# Or wait for automatic sync (if enabled)
```

#### 3. Monitor Upgrade

Watch the upgrade progress:

```bash
# Watch pods
kubectl get pods -n authentik -w

# Check Argo CD application status
argocd app get authentik
```

## Verify Your Upgrade

You can view the current version of your authentik instance by:

1. Logging in to the Admin interface
2. Navigating to **Dashboards > Overview**

The version number will be displayed in the overview dashboard.

Alternatively, check the version via API:

```bash
# Get version from API
curl -k https://authentik.domain.tld/api/v3/core/version/ | jq .
```

## Troubleshooting Your Upgrade

### Version Not Updating

If you run the upgrade commands but your version on the Dashboard doesn't change, follow these steps:

1. **Check Server Logs:**
   ```bash
   # Docker Compose
   docker compose logs server | grep -i migration
   
   # Kubernetes
   kubectl logs -n authentik -l app.kubernetes.io/name=authentik --tail=100 | grep -i migration
   ```

2. **Look for Migration Inconsistency:**
   - Search for entries about "migration inconsistency" in the logs
   - If you see this entry, it indicates a database migration issue

3. **Revert to Database Backup:**
   ```bash
   # Restore from backup
   # Docker Compose
   docker compose exec postgresql psql -U authentik -d authentik < backup.sql
   
   # Kubernetes
   kubectl exec -n platform platform-postgres-0 -- psql -U zalando -d authentik < backup.sql
   ```

4. **Upgrade in Sequence:**
   - Now, upgrade to each subsequent higher version
   - Do not skip directly to the most recent version
   - Follow the upgrade sequence: 2025.2.x → 2025.4.x → 2025.6.x

### Pods Not Starting

If pods fail to start after upgrade:

1. **Check Pod Status:**
   ```bash
   kubectl describe pod -n authentik <pod-name>
   ```

2. **Check Logs:**
   ```bash
   kubectl logs -n authentik <pod-name> --previous
   ```

3. **Verify Database Connection:**
   - Ensure PostgreSQL is accessible
   - Check credentials are correct
   - Verify network policies allow connection

### Database Migration Errors

If you encounter database migration errors:

1. **Check Migration Status:**
   ```bash
   kubectl logs -n authentik -l app.kubernetes.io/name=authentik | grep -i migration
   ```

2. **Review Release Notes:**
   - Check if the target version requires manual migration steps
   - Look for breaking changes in database schema

3. **Contact Support:**
   - If migration fails, contact Authentik support with:
     - Current version
     - Target version
     - Error logs
     - Database backup (if possible)

## Pre-Upgrade Checklist

Before starting an upgrade, ensure you have:

- [ ] Read the release notes for the target version
- [ ] Created a database backup
- [ ] Verified current version
- [ ] Identified all outposts that need upgrading
- [ ] Planned the upgrade sequence (if upgrading across major versions)
- [ ] Scheduled a maintenance window (for production)
- [ ] Notified users (if required)

## Post-Upgrade Checklist

After upgrading, verify:

- [ ] Authentik server is running and accessible
- [ ] Version displayed in dashboard matches target version
- [ ] All outposts are upgraded and connected
- [ ] Database migrations completed successfully
- [ ] Authentication flows are working
- [ ] Applications can authenticate users
- [ ] No errors in server logs
- [ ] Performance is acceptable

## Rollback Procedure

If you need to rollback after an upgrade:

1. **Stop Authentik:**
   ```bash
   # Docker Compose
   docker compose down
   
   # Kubernetes
   kubectl scale deployment authentik -n authentik --replicas=0
   ```

2. **Restore Database Backup:**
   ```bash
   # Restore from backup created before upgrade
   # See backup restoration commands above
   ```

3. **Revert to Previous Version:**
   ```bash
   # Docker Compose - update docker-compose.yml with previous version
   docker compose pull
   docker compose up -d
   
   # Kubernetes - update Helm chart version
   helm upgrade authentik authentik/authentik \
     --namespace authentik \
     --version <previous-version> \
     -f values.yaml
   ```

4. **Verify Rollback:**
   - Check version in dashboard
   - Verify functionality
   - Check logs for errors

## Additional Resources

- [Authentik Release Notes](https://goauthentik.io/docs/releases/)
- [Authentik Documentation](https://goauthentik.io/docs/)
- [Docker Compose Installation Guide](https://goauthentik.io/docs/installation/docker-compose/)
- [Kubernetes Installation Guide](https://goauthentik.io/docs/installation/kubernetes/)
- [Authentik GitHub Repository](https://github.com/goauthentik/authentik)


