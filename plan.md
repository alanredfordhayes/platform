# Platform Engineering Demo - Implementation Plan

## Overview

This plan outlines the structure and implementation for a self-service platform engineering demo showcasing modern cloud-native technologies. The platform will be organized using GitOps principles with Argo CD managing deployments through an app-of-apps pattern, Argo Workflows handling CI/CD builds, and Harbor serving as the container registry.

## Repository Structure

```
platform/
├── argocd/
│   ├── app-of-apps/
│   │   ├── apps/
│   │   │   ├── automation-parent.yaml          # Parent app for automation category
│   │   │   ├── automation/                     # Automation child apps
│   │   │   │   ├── argocd.yaml                 # Argo CD (self-managed)
│   │   │   │   ├── argo-workflows.yaml         # Argo Workflows
│   │   │   │   ├── crossplane.yaml             # Crossplane
│   │   │   │   ├── harbor.yaml                 # Harbor registry
│   │   │   │   └── backstage.yaml              # Backstage developer portal
│   │   │   ├── security-parent.yaml            # Parent app for security category
│   │   │   ├── security/                       # Security child apps
│   │   │   │   ├── vault.yaml                  # HashiCorp Vault
│   │   │   │   ├── external-secrets.yaml       # External Secrets Operator
│   │   │   │   └── authentik.yaml              # Authentik
│   │   │   ├── observability-parent.yaml       # Parent app for observability category
│   │   │   ├── observability/                  # Observability child apps
│   │   │   │   └── alloy.yaml                  # Grafana Alloy
│   │   │   ├── network-parent.yaml             # Parent app for network category
│   │   │   ├── network/                        # Network child apps
│   │   │   │   └── traefik.yaml                # Traefik (existing)
│   │   │   └── platform/                       # Platform infrastructure
│   │   │       └── postgresql.yaml            # Shared PostgreSQL database
│   │   └── projects/                           # Argo CD Projects
│   │       ├── automation-project.yaml         # Automation project
│   │       ├── security-project.yaml           # Security project
│   │       ├── observability-project.yaml      # Observability project
│   │       └── network-project.yaml            # Network project
│   └── workflows/                              # Argo Workflow templates
│       ├── build-image-workflow.yaml          # Generic image build workflow
│       └── build-backstage-workflow.yaml      # Backstage-specific build workflow
├── vault/                                      # Vault configuration (existing)
└── plan.md                                     # This document
```

## Technology Categories

### Automation
- **Argo CD**: GitOps continuous delivery (self-managed)
- **Argo Workflows**: Workflow engine for CI/CD pipelines
- **Crossplane**: Cloud-native control plane for infrastructure
- **Harbor**: Container registry
- **Backstage**: Developer portal

### Security
- **Vault**: Secrets management (existing)
- **External Secrets**: Kubernetes secrets integration
- **Authentik**: Identity and access management

### Observability
- **Alloy**: Grafana's telemetry collector (sends to Grafana Cloud)

### Network
- **Traefik**: Ingress controller (existing)

## Version Management

All technology versions are determined using Context7 MCP to ensure we're using current, stable versions. This includes:
- Helm chart versions
- Container image tags
- Application versions
- Plugin versions (for Backstage)

The Context7 MCP is used to:
1. Resolve library/package names to Context7-compatible IDs
2. Retrieve documentation and version information
3. Ensure compatibility between related technologies

### Current Versions (as of implementation)

- **Argo Workflows**: Helm chart 0.47.0
- **Crossplane**: Helm chart 1.16.0
- **Harbor**: Helm chart 1.15.0
- **External Secrets**: Helm chart 0.10.0
- **Authentik**: Helm chart 2024.10.0
- **Alloy**: Kubernetes Monitoring Helm chart (latest)

## Implementation Steps

### Phase 0: Bootstrap Argo CD

**Important**: Argo CD must be deployed manually first before it can manage itself. This is a one-time bootstrap process.

#### Option 1: Manual Helm Installation (Recommended for Bootstrap)

1. **Add Argo CD Helm Repository:**
   ```bash
   helm repo add argo https://argoproj.github.io/argo-helm
   helm repo update
   ```

2. **Create Namespace:**
   ```bash
   kubectl create namespace argocd
   ```

3. **Install Argo CD:**
   ```bash
   helm install argocd argo/argo-cd \
     --namespace argocd \
     --version <latest-version> \
     --set controller.replicas=1 \
     --set server.replicas=1 \
     --set repoServer.replicas=1 \
     --set applicationSet.replicas=1 \
     --set dex.enabled=false \
     --set notifications.enabled=true \
     --set redis.enabled=true
   ```

4. **Wait for Argo CD to be Ready:**
   ```bash
   kubectl wait --for=condition=ready pod \
     -l app.kubernetes.io/name=argocd-server \
     -n argocd \
     --timeout=300s
   ```

5. **Get Initial Admin Password:**
   ```bash
   # For Argo CD 2.4+
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
   
   # For older versions
   kubectl -n argocd get secret argocd-secret -o jsonpath="{.data.admin\.password}" | base64 -d; echo
   ```

6. **Access Argo CD UI:**
   ```bash
   # Port-forward to access the UI
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```
   
   Then open `https://localhost:8080` in your browser (accept the self-signed certificate).

7. **Login:**
   - Username: `admin`
   - Password: (from step 5)

8. **Install Argo CD CLI (Optional but Recommended):**
   ```bash
   # macOS
   brew install argocd
   
   # Linux
   curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
   chmod +x /usr/local/bin/argocd
   ```

9. **Login via CLI:**
   ```bash
   argocd login localhost:8080 --insecure --username admin --password <password-from-step-5>
   ```

10. **Create Automation Project:**
    ```bash
    kubectl apply -f argocd/app-of-apps/projects/automation-project.yaml
    ```

11. **Deploy Automation Parent App:**
    ```bash
    kubectl apply -f argocd/app-of-apps/apps/automation-parent.yaml
    ```

12. **Sync Automation Parent App:**
    ```bash
    argocd app sync automation-parent
    ```

13. **Transition to Self-Managed:**
    Once the automation-parent app is synced and the `argocd.yaml` child app is created, Argo CD will manage itself. You can then:
    - Update the bootstrap Argo CD installation to match the self-managed configuration
    - Or leave the bootstrap installation as-is and let the self-managed instance take over

#### Option 2: Using kubectl apply (Alternative)

If you prefer to use raw manifests:

1. **Download Argo CD Manifests:**
   ```bash
   curl -sSL -o argocd-install.yaml https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

2. **Apply Manifests:**
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f argocd-install.yaml
   ```

3. **Follow steps 4-13 from Option 1**

#### Troubleshooting Bootstrap

**Issue: Argo CD pods not starting**
- Check pod logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server`
- Verify RBAC: `kubectl get clusterrolebinding | grep argocd`
- Check resource quotas: `kubectl describe namespace argocd`

**Issue: Cannot access Argo CD UI**
- Verify service exists: `kubectl get svc -n argocd argocd-server`
- Check ingress configuration if using ingress
- Verify port-forward is working: `kubectl port-forward -n argocd svc/argocd-server 8080:443`

**Issue: Cannot login**
- Verify secret exists: `kubectl get secret -n argocd argocd-initial-admin-secret`
- Reset admin password if needed:
  ```bash
  kubectl -n argocd patch secret argocd-secret \
    -p '{"stringData":{"admin.password":"$2a$10$<bcrypt-hash>"}}'
  ```

### Phase 1: Foundation Setup

1. **Argo CD** (self-managed - deploy first)
   - Use Context7 MCP to get latest version
   - Create `argocd/app-of-apps/apps/automation/argocd.yaml`
   - Configure for GitOps continuous delivery
   - See Argo CD Application manifest below
   - **Note**: After bootstrap (Phase 0), Argo CD will manage itself via this manifest

2. Create observability project and parent app
   - `argocd/app-of-apps/projects/observability-project.yaml`
   - `argocd/app-of-apps/apps/observability-parent.yaml`
3. Update existing parent apps if needed
4. Document app-of-apps pattern structure
5. Use Context7 MCP to determine current versions for all technologies

#### Argo CD Self-Managed Deployment

Argo CD must be deployed first as it manages all other platform components. For self-managed deployment, use the official Helm chart:

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
  project: automation
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argo-cd
    targetRevision: <latest-version>  # Use Context7 MCP to get latest version
    helm:
      valueFiles:
        - $values/argocd-values.yaml
      values: |
        global:
          image:
            tag: <latest-version>
        controller:
          replicas: 2
          resources:
            limits:
              cpu: 1000m
              memory: 1Gi
            requests:
              cpu: 100m
              memory: 128Mi
        server:
          replicas: 2
          ingress:
            enabled: true
            ingressClassName: traefik
            hosts:
              - argocd.example.com
            tls:
              - secretName: argocd-tls
                hosts:
                  - argocd.example.com
          config:
            url: https://argocd.example.com
            oidc.config: |
              name: Authentik
              issuer: https://authentik.company/application/o/argocd
              clientId: $ARGOCD_OIDC_CLIENT_ID
              clientSecret: $ARGOCD_OIDC_CLIENT_SECRET
              requestedScopes: ["openid", "profile", "email", "groups"]
        repoServer:
          replicas: 2
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 100m
              memory: 128Mi
        applicationSet:
          replicas: 2
        notifications:
          enabled: true
        dex:
          enabled: false  # Disable if using external OIDC (Authentik)
        redis:
          enabled: true
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
            requests:
              cpu: 50m
              memory: 64Mi
        configs:
          cm:
            application.instanceLabelKey: argocd.argoproj.io/instance
            application.statusBadge.enabled: "true"
          params:
            server.insecure: "false"
            server.staticassets: "true"
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
      namespace: argocd
      jsonPointers:
        - /data
    - group: ""
      kind: ConfigMap
      namespace: argocd
      jsonPointers:
        - /data
```

**Key Configuration Points:**

- **High Availability**: Set replica counts for all components
- **OIDC Integration**: Configure Authentik for SSO (disable Dex)
- **Ingress**: Configure Traefik ingress for UI access
- **Resources**: Configure appropriate resource limits
- **Notifications**: Enable notifications for application events
- **Self-Managed**: This Argo CD instance manages itself (bootstrap)

**Important Notes:**

- Argo CD must be deployed manually first (bootstrap) or via another GitOps tool
- After initial deployment, this manifest can be managed by Argo CD itself
- OIDC configuration requires Authentik to be deployed and configured first
- Use External Secrets for OIDC client credentials

### Phase 1.5: Shared PostgreSQL Database

This phase deploys the shared PostgreSQL cluster and Redis that will be used by all platform components.

#### Deploy Zalando Postgres Operator

The Zalando Postgres Operator will be used to manage PostgreSQL clusters. Deploy it using Helm:

1. **Add Helm Repository:**
   ```bash
   helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
   helm repo update
   ```

2. **Install Postgres Operator:**
   - Create `argocd/app-of-apps/apps/platform/postgres-operator.yaml`
   - Deploy via Argo CD Application manifest:
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: postgres-operator
     namespace: argocd
   spec:
     destination:
       namespace: postgres-operator
       server: https://kubernetes.default.svc
     project: automation
     source:
       repoURL: https://opensource.zalando.com/postgres-operator/charts/postgres-operator
       chart: postgres-operator
       targetRevision: 1.10.0
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
       syncOptions:
         - CreateNamespace=true
   ```

3. **Verify Operator is Running:**
   
   Starting the operator may take a few seconds. Check if the operator pod is running before applying a Postgres cluster manifest:
   
   ```bash
   # For Helm chart deployment
   kubectl get pod -l app.kubernetes.io/name=postgres-operator -n postgres-operator
   
   # For YAML manifest deployment (alternative)
   kubectl get pod -l name=postgres-operator -n postgres-operator
   ```
   
   If the operator doesn't get into Running state, check the latest K8s events or inspect the operator logs:
   
   ```bash
   # Check pod events
   kubectl describe pod -l app.kubernetes.io/name=postgres-operator -n postgres-operator
   
   # View operator logs
   kubectl logs "$(kubectl get pod -l app.kubernetes.io/name=postgres-operator -n postgres-operator --output='name')" -n postgres-operator
   ```

4. **Deploy Postgres Operator UI (Optional but Recommended):**
   
   The Postgres Operator UI provides a browser-based interface for managing PostgreSQL clusters. Before deploying the UI, ensure the operator is running and its REST API is reachable through a K8s service.
   
   **Deploy UI via Helm Chart:**
   - Create `argocd/app-of-apps/apps/platform/postgres-operator-ui.yaml`
   - Deploy via Argo CD Application manifest:
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: postgres-operator-ui
     namespace: argocd
   spec:
     destination:
       namespace: postgres-operator
       server: https://kubernetes.default.svc
     project: automation
     source:
       repoURL: https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui
       chart: postgres-operator-ui
       targetRevision: 1.10.0
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
       syncOptions:
         - CreateNamespace=true
   ```
   
   **Verify UI is Running:**
   ```bash
   # For Helm chart deployment
   kubectl get pod -l app.kubernetes.io/name=postgres-operator-ui -n postgres-operator
   
   # For YAML manifest deployment (alternative)
   kubectl get pod -l name=postgres-operator-ui -n postgres-operator
   ```
   
   **Access the UI:**
   ```bash
   # Port-forward to access the web interface
   kubectl port-forward svc/postgres-operator-ui 8081:80 -n postgres-operator
   ```
   
   Then open `http://localhost:8081` in your browser. Available options are explained in detail in the [UI documentation](https://github.com/zalando/postgres-operator/blob/master/docs/user.md#ui).

#### Deploy Redis (Shared Cache)

Redis will be used by Harbor and other components that require caching.

1. **Create Redis Argo CD Application:**
   - Create `argocd/app-of-apps/apps/platform/redis.yaml`
   - See Redis Argo CD Application manifest below

2. **Create External Secret for Redis Password:**
   ```yaml
   apiVersion: external-secrets.io/v1beta1
   kind: ExternalSecret
   metadata:
     name: redis-password
     namespace: platform
   spec:
     secretStoreRef:
       name: vault-backend
       kind: SecretStore
     target:
       name: redis-password
       creationPolicy: Owner
     data:
       - secretKey: REDIS_PASSWORD
         remoteRef:
           key: platform/redis/password
   ```

3. **Verify Redis Deployment:**
   ```bash
   # Check Redis pods
   kubectl get pods -n platform -l app.kubernetes.io/name=redis
   
   # Check Redis services
   kubectl get svc -n platform -l app.kubernetes.io/name=redis
   
   # Test Redis connection (from within cluster)
   kubectl run -it --rm redis-test --image=redis:7-alpine --restart=Never -n platform -- \
     redis-cli -h redis.platform.svc.cluster.local -a $(kubectl get secret redis -n platform -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d)
   ```

**Redis Connection Details:**
- **Master Service**: `redis-master.platform.svc.cluster.local:6379`
- **Replica Service**: `redis-replica.platform.svc.cluster.local:6379`
- **Headless Service**: `redis.platform.svc.cluster.local:6379` (for direct pod access)
- **Password**: Stored in `redis` secret in `platform` namespace (managed by External Secrets)

#### Redis Argo CD Application Manifest

The Redis deployment manifest is located at `argocd/app-of-apps/apps/platform/redis.yaml`. See the file for complete configuration.

**Key Configuration Points:**

- **High Availability**: Replication mode with 1 master and 2 replicas
- **Persistence**: Enabled with 10Gi storage per instance
- **Authentication**: Password-protected (managed via External Secrets)
- **Metrics**: Prometheus metrics enabled
- **Resources**: Appropriate limits for shared platform use

#### Platform Infrastructure Summary

After completing Phase 1.5, you will have:

- **PostgreSQL Cluster**: `platform-postgres.platform.svc.cluster.local:5432`
  - Databases: `authentik`, `backstage`, `harbor`, `argo_workflows`
  - User: `zalando` (superuser, createdb)
  - Connection Pooler: `platform-postgres-pooler.platform.svc.cluster.local:5432`
  
- **Redis Cluster**: `redis.platform.svc.cluster.local:6379`
  - Master: `redis-master.platform.svc.cluster.local:6379`
  - Replicas: `redis-replica.platform.svc.cluster.local:6379`
  - Password: Managed via External Secrets

All components will use these shared infrastructure services.

#### Create PostgreSQL Cluster

1. **Create PostgreSQL Cluster Manifest:**
   - Create `argocd/app-of-apps/apps/platform/postgresql-cluster.yaml`
   - Define PostgreSQL cluster using `postgresql` CustomResource:
   ```yaml
   apiVersion: "acid.zalan.do/v1"
   kind: postgresql
   metadata:
     name: platform-postgres
     namespace: platform
   spec:
     teamId: "platform"
     volume:
       size: 50Gi
     numberOfInstances: 2
     users:
       # Database users will be created automatically
       zalando:
       - superuser
       - createdb
     databases:
       authentik: zalando
       backstage: zalando
     postgresql:
       version: "15"
     resources:
       requests:
         cpu: 500m
         memory: 500Mi
       limits:
         cpu: 2000m
         memory: 2Gi
     enableMasterLoadBalancer: false
     enableReplicaLoadBalancer: false
   ```

2. **Deploy Cluster via Argo CD:**
   - The cluster will be managed by Argo CD
   - Operator will create StatefulSet, Services, and Endpoints automatically

3. **Verify Cluster Deployment:**
   
   After the cluster manifest is submitted and passes validation, the operator will create Service and Endpoint resources and a StatefulSet which spins up new Pod(s) based on the number of instances specified. All resources are named like the cluster. The database pods can be identified by their number suffix, starting from `-0`. They run the Spilo container image by Zalando. As for the services and endpoints, there will be one for the master pod and another one for all the replicas (`-repl` suffix).
   
   ```bash
   # Check PostgreSQL cluster
   kubectl get postgresql -n platform
   
   # Check created database pods (use label application=spilo to filter)
   kubectl get pods -l application=spilo -n platform -L spilo-role
   
   # Check created service resources
   kubectl get svc -l application=spilo -n platform -L spilo-role
   ```
   
   The `spilo-role` label will show which pod is currently the master.

4. **Retrieve Connection Information:**
   - Master service: `platform-postgres.platform.svc.cluster.local`
   - Replica service: `platform-postgres-repl.platform.svc.cluster.local`
   - Credentials stored in Kubernetes Secret: `postgres.platform-postgres.credentials.postgresql.acid.zalan.do`
   - Store credentials in Vault and use External Secrets Operator for applications

5. **Configure Databases:**
   - Databases `authentik` and `backstage` will be created automatically
   - Additional databases can be added to the `databases` section
   - Users and permissions are managed via the operator

6. **Connection Pooling (Optional):**
   - PgBouncer can be configured if needed
   - Adjust Authentik connection settings accordingly (see Authentik PostgreSQL Configuration)

7. **Connect to Postgres Cluster via psql:**
   
   You can create a port-forward on a database pod to connect to Postgres:
   
   ```bash
   # Port-forward to master pod
   kubectl port-forward -n platform platform-postgres-0 5432:5432
   ```
   
   Retrieve the password from the Kubernetes Secret:
   
   ```bash
   # Get password for postgres user
   export PGPASSWORD=$(kubectl get secret postgres.platform-postgres.credentials.postgresql.acid.zalan.do \
     -n platform \
     -o 'jsonpath={.data.password}' | base64 -d)
   
   # Set SSL mode (required by default)
   export PGSSLMODE=require
   
   # Connect via psql
   psql -h localhost -U postgres -d postgres
   ```
   
   For the `zalando` user (used by Authentik and Backstage):
   
   ```bash
   export PGPASSWORD=$(kubectl get secret zalando.platform-postgres.credentials.postgresql.acid.zalan.do \
     -n platform \
     -o 'jsonpath={.data.password}' | base64 -d)
   
   psql -h localhost -U zalando -d authentik
   ```

8. **Delete a Postgres Cluster:**
   
   To delete a Postgres cluster, simply delete the `postgresql` custom resource:
   
   ```bash
   kubectl delete postgresql platform-postgres -n platform
   ```
   
   This will remove:
   - Associated StatefulSet
   - Database Pods
   - Services and Endpoints
   - PersistentVolumes (released)
   - PodDisruptionBudget
   
   **Note**: Secrets are NOT deleted and backups will remain in place.
   
   **Warning**: When deleting a cluster while it is still starting up or got stuck during that phase, it can happen that the `postgresql` resource is deleted leaving orphaned components behind. This can cause troubles when creating a new Postgres cluster. For a fresh setup, you may need to manually clean up orphaned resources or recreate the namespace.

**Important**: 
- PostgreSQL cluster must be fully deployed and accessible before deploying Authentik and Backstage
- Database credentials should be stored in Vault and retrieved via External Secrets Operator
- The operator automatically handles backups, high availability, and failover
- Always verify the operator is running before creating clusters
- Use the operator UI for easier cluster management and monitoring

### Phase 2: Automation Technologies
1. **Argo Workflows**
   - Use Context7 MCP to get latest stable version
   - Create `argocd/app-of-apps/apps/automation/argo-workflows.yaml`
   - Configure workflow templates for CI/CD
   - Set up Harbor integration for image pushes

2. **Crossplane**
   - Use Context7 MCP to get latest stable version
   - Create `argocd/app-of-apps/apps/automation/crossplane.yaml`
   - Configure providers (AWS, GCP, Azure, etc.)

3. **Harbor**
   - Use Context7 MCP to get latest stable version
   - Create `argocd/app-of-apps/apps/automation/harbor.yaml`
   - Configure registry endpoints
   - Set up authentication
   - Configure as target registry for all builds

#### Argo Workflows Argo CD Application Manifest

Create an Argo CD Application manifest for Argo Workflows:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argo-workflows
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app.kubernetes.io/instance: automation
    app.kubernetes.io/name: argo-workflows
spec:
  destination:
    namespace: argo
    server: https://kubernetes.default.svc
  project: automation
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argo-workflows
    targetRevision: <latest-version>  # Use Context7 MCP to get latest version
    helm:
      valueFiles:
        - $values/argo-workflows-values.yaml
      values: |
        controller:
          replicaCount: 2
          metricsConfig:
            enabled: true
          persistence:
            archive: true
            postgresql:
              host: platform-postgres.platform.svc.cluster.local
              port: 5432
              database: argo_workflows
              tableName: argo_workflows
              userName: zalando
              password: "env://ARGO_WORKFLOWS_DB_PASSWORD"
        server:
          enabled: true
          replicaCount: 2
          ingress:
            enabled: true
            ingressClassName: traefik
            hosts:
              - host: argo-workflows.example.com
                paths:
                  - /
            tls:
              - secretName: argo-workflows-tls
                hosts:
                  - argo-workflows.example.com
        workflow:
          serviceAccount:
            create: true
            name: argo-workflow
        singleNamespace: false
        useDefaultArtifactRepo: true
        artifactRepository:
          archiveLogs: true
          s3:
            bucket: argo-workflows
            endpoint: harbor.example.com
            insecure: false
            accessKeySecret:
              name: harbor-credentials
              key: username
            secretKeySecret:
              name: harbor-credentials
              key: password
            useSDKCreds: false
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
      namespace: argo
      jsonPointers:
        - /data
    - group: ""
      kind: ConfigMap
      namespace: argo
      jsonPointers:
        - /data
```

**Key Configuration Points:**

- **PostgreSQL Backend**: Use shared PostgreSQL cluster for workflow persistence
- **High Availability**: Set replica counts for controller and server
- **Artifact Storage**: Configure Harbor as artifact repository
- **Database Credentials**: Use External Secrets for database password
- **Ingress**: Configure Traefik ingress for UI access

**External Secret for Database Password:**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: argo-workflows-postgres
  namespace: argo
spec:
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: argo-workflows-postgres
    creationPolicy: Owner
  data:
    - secretKey: ARGO_WORKFLOWS_DB_PASSWORD
      remoteRef:
        key: platform/argo-workflows/db-password
```

#### Crossplane Argo CD Application Manifest

Create an Argo CD Application manifest for Crossplane:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: crossplane
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app.kubernetes.io/instance: automation
    app.kubernetes.io/name: crossplane
spec:
  destination:
    namespace: crossplane-system
    server: https://kubernetes.default.svc
  project: automation
  source:
    repoURL: https://charts.crossplane.io/stable
    chart: crossplane
    targetRevision: <latest-version>  # Use Context7 MCP to get latest version
    helm:
      valueFiles:
        - $values/crossplane-values.yaml
      values: |
        replicaCount: 2
        resources:
          limits:
            cpu: 1000m
            memory: 1Gi
          requests:
            cpu: 100m
            memory: 128Mi
        args:
          - --enable-usages
        rbacManager:
          replicaCount: 2
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 100m
              memory: 128Mi
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
      namespace: crossplane-system
      jsonPointers:
        - /data
    - group: ""
      kind: ConfigMap
      namespace: crossplane-system
      jsonPointers:
        - /data
```

**Key Configuration Points:**

- **High Availability**: Set replica counts for controller and RBAC manager
- **Resources**: Configure appropriate resource limits
- **Usage Tracking**: Enable usage tracking with `--enable-usages`
- **Providers**: Install Crossplane providers after deployment

**Example Provider Installation:**

After Crossplane is deployed, install providers:

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.12.0
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-helm
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-helm:v0.18.0
```

#### Harbor Argo CD Application Manifest

Create an Argo CD Application manifest for Harbor (see Harbor Helm Chart Configuration section above for detailed values):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: harbor
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app.kubernetes.io/instance: automation
    app.kubernetes.io/name: harbor
spec:
  destination:
    namespace: harbor
    server: https://kubernetes.default.svc
  project: automation
  source:
    repoURL: https://helm.goharbor.io
    chart: harbor
    targetRevision: <latest-version>  # Use Context7 MCP to get latest version
    helm:
      valueFiles:
        - $values/harbor-values.yaml
      values: |
        externalURL: https://harbor.example.com
        expose:
          type: ingress
          tls:
            enabled: true
            certSource: auto
          ingress:
            hosts:
              core: harbor.example.com
            className: traefik
            annotations:
              cert-manager.io/cluster-issuer: "letsencrypt-prod"
        harborAdminPassword: "env://HARBOR_ADMIN_PASSWORD"
        persistence:
          enabled: true
          resourcePolicy: keep
          persistentVolumeClaim:
            registry:
              size: 50Gi
              storageClass: fast-ssd
        database:
          type: external
          external:
            host: platform-postgres.platform.svc.cluster.local:5432
            port: 5432
            username: "env://HARBOR_DB_USER"
            password: "env://HARBOR_DB_PASSWORD"
            coreDatabase: harbor
            existingSecret: harbor-db-secret
            sslmode: require
        redis:
          type: external
          external:
            addr: redis.platform.svc.cluster.local:6379
            existingSecret: harbor-redis-secret
        oidc:
          name: authentik
          endpoint: https://authentik.company/application/o/harbor
          clientID: "env://HARBOR_OIDC_CLIENT_ID"
          clientSecret: "env://HARBOR_OIDC_CLIENT_SECRET"
          scope: "openid,profile,email,offline_access"
          usernameClaim: "preferred_username"
        trivy:
          enabled: true
          severity: UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL
        metrics:
          enabled: true
          serviceMonitor:
            enabled: true
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
      namespace: harbor
      jsonPointers:
        - /data
    - group: ""
      kind: ConfigMap
      namespace: harbor
      jsonPointers:
        - /data
    - group: ""
      kind: PersistentVolumeClaim
      namespace: harbor
      jsonPointers:
        - /status
```

**External Secrets for Harbor:**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: harbor-db-secret
  namespace: harbor
spec:
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: harbor-db-secret
    creationPolicy: Owner
  data:
    - secretKey: HARBOR_ADMIN_PASSWORD
      remoteRef:
        key: platform/harbor/admin-password
    - secretKey: HARBOR_DB_USER
      remoteRef:
        key: platform/harbor/db-user
    - secretKey: HARBOR_DB_PASSWORD
      remoteRef:
        key: platform/harbor/db-password
    - secretKey: HARBOR_OIDC_CLIENT_ID
      remoteRef:
        key: platform/harbor/oidc-client-id
    - secretKey: HARBOR_OIDC_CLIENT_SECRET
      remoteRef:
        key: platform/harbor/oidc-client-secret
```

### Argo Workflows Quick Start

To try out Argo Workflows, you can install it and run example workflows.

**Note:** These instructions are intended to help you get started quickly. They are not suitable for production. For production installs, please refer to the installation documentation.

#### Prerequisites

Before installing Argo, you need a Kubernetes cluster and kubectl configured to access it. For quick testing, you can use a local cluster with:

- minikube
- kind
- k3s or k3d
- Docker Desktop

#### Install Argo Workflows

First, specify the version you want to install in an environment variable. Modify the command below:

```bash
ARGO_WORKFLOWS_VERSION="vX.Y.Z"
```

Then, copy the commands below to apply the quick-start manifest:

```bash
kubectl create namespace argo
kubectl apply -n argo -f "https://github.com/argoproj/argo-workflows/releases/download/${ARGO_WORKFLOWS_VERSION}/quick-start-minimal.yaml"
```

#### Install the Argo Workflows CLI

You can more easily interact with Argo Workflows with the Argo CLI. Install it using one of the following methods:

**macOS:**
```bash
brew install argo
```

**Linux:**
```bash
# Download the latest binary
curl -sLO https://github.com/argoproj/argo-workflows/releases/latest/download/argo-linux-amd64.gz
gunzip argo-linux-amd64.gz
chmod +x argo-linux-amd64
sudo mv argo-linux-amd64 /usr/local/bin/argo
```

**Windows:**
```powershell
# Download from GitHub releases
# Extract and add to PATH
```

#### Submit an Example Workflow

**Submit via the CLI:**

```bash
argo submit -n argo --watch https://raw.githubusercontent.com/argoproj/argo-workflows/main/examples/hello-world.yaml
```

The `--watch` flag watches the workflow as it runs and reports whether it succeeds or not. When the workflow completes, the watch stops.

**List all submitted Workflows:**

```bash
argo list -n argo
```

The Workflow name has a `hello-world-` prefix followed by random characters. These characters give Workflows unique names to help identify specific runs of a Workflow. If you submit this Workflow again, the next run will have different characters.

**Review Workflow Details:**

You can review the details of a Workflow run using the `argo get` command. The output for the command below will be the same as the information shown when you submitted the Workflow:

```bash
argo get -n argo @latest
```

The `@latest` argument is a shortcut to view the latest Workflow run.

**View Workflow Logs:**

You can observe the logs of the Workflow run with the following command:

```bash
argo logs -n argo @latest
```

**Submit via the UI:**

1. Forward the Server's port to access the UI:
   ```bash
   kubectl -n argo port-forward service/argo-server 2746:2746
   ```

2. Navigate your browser to `https://localhost:2746`.

   **Note:** The URL uses `https` and not `http`. Navigating to `http` will result in a server-side error.

   Due to the self-signed certificate, you will receive a TLS error which you will need to manually approve.

3. Click **+ Submit New Workflow** and then **Edit using full workflow options**

4. You can find an example workflow already in the text field. Press **+ Create** to start the workflow.

### Argo Workflows Installation

#### Non-Production Installation

If you just want to try out Argo Workflows in a non-production environment (including on desktop via minikube/kind/k3d etc) follow the quick-start guide above.

#### Production Installation

**Installation Methods:**

There are several ways to install Argo Workflows for production:

1. **Official release manifests**
2. **Argo Workflows Helm Chart** (community maintained)
3. **Full CRDs** (for server-side apply)

#### Official Release Manifests

To install Argo Workflows, navigate to the [releases page](https://github.com/argoproj/argo-workflows/releases) and find the release you wish to use (the latest full release is preferred). Scroll down to the Controller and Server section and execute the kubectl commands.

You can use Kustomize to patch your preferred configurations on top of the base manifest.

**Important Notes:**

- **Use a full hash**: If you are using a remote base with Kustomize, you should specify a full commit hash, for example `?ref=960af331a8c0a3f2e263c8b90f1daf4303816ba8`.
- **latest vs stable**: `latest` is the tip of the main branch and may not be stable. In production, you should use a specific release version.

#### Argo Workflows Helm Chart

You can install Argo Workflows using the community maintained Helm charts. This is the recommended approach for production deployments as it provides better configuration management and version control.

**Example Installation:**

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argo-workflows argo/argo-workflows -n argo --create-namespace
```

#### Full CRDs

The official release manifests come with stripped-down CRDs that omit validation information. This is a workaround for Kubernetes size limitations when using client-side apply. As of version 3.7, the full CRDs can be installed using server-side apply via the following command:

```bash
kubectl apply --server-side --kustomize https://github.com/argoproj/argo-workflows/manifests/base/crds/full?ref=v3.7.0
```

#### Installation Options

Determine your base installation option:

1. **Cluster Install**: Will watch and execute workflows in all namespaces. This is the default installation option when installing using the official release manifests.

2. **Namespace Install**: Only executes workflows in the namespace it is installed in (typically `argo`). Look for `namespace-install.yaml` in the release assets.

3. **Managed Namespace Install**: Only executes workflows in a separate namespace from the one it is installed in. See Managed Namespace for more details.

#### Additional Installation Considerations

Before deploying to production, review the following:

- **Workflow RBAC**: Configure appropriate role-based access control for workflows
- **Security**: Review security best practices and configure authentication/authorization
- **Scaling and Running at Massive Scale**: Plan for horizontal scaling and resource requirements
- **High-Availability**: Configure for high availability if required
- **Disaster Recovery**: Plan backup and recovery procedures

**Getting Help:**

- Search on [GitHub Discussions](https://github.com/argoproj/argo-workflows/discussions)
- Join the [Argo Slack](https://argoproj.github.io/community/join-slack)

### Crossplane Installation

Crossplane installs into an existing Kubernetes cluster, creating the Crossplane pod. Installing Crossplane enables the installation of Crossplane Provider, Function, and Configuration resources.

**Tip:** If you don't have a Kubernetes cluster, create one locally with [Kind](https://kind.sigs.k8s.io/).

#### Prerequisites

- An actively supported Kubernetes version
- Helm version v3.2.0 or later

#### Install Crossplane

Install Crossplane using the Helm chart.

**Add the Crossplane Helm Repository:**

Add the Crossplane stable repository with the `helm repo add` command:

```bash
helm repo add crossplane-stable https://charts.crossplane.io/stable
```

Update the local Helm chart cache with `helm repo update`:

```bash
helm repo update
```

**Install the Crossplane Helm Chart:**

Install the Crossplane Helm chart with `helm install`.

**Tip:** View the changes Crossplane makes to your cluster with the `helm install --dry-run --debug` options. Helm shows what configurations it applies without making changes to the Kubernetes cluster.

Crossplane creates and installs into the `crossplane-system` namespace:

```bash
helm install crossplane \
  --namespace crossplane-system \
  --create-namespace crossplane-stable/crossplane
```

View the installed Crossplane pods with `kubectl get pods -n crossplane-system`:

```bash
kubectl get pods -n crossplane-system

NAME                                       READY   STATUS    RESTARTS   AGE
crossplane-6d67f8cd9d-g2gjw                1/1     Running   0          26m
crossplane-rbac-manager-86d9b5cf9f-2vc4s   1/1     Running   0          26m
```

#### Installation Options

**Customize the Crossplane Helm Chart:**

Crossplane supports customizations at install time by configuring the Helm chart.

- Read the [Helm chart README](https://github.com/crossplane/crossplane/tree/master/cluster/charts/crossplane) to learn what customizations are available
- Read the [Helm documentation](https://helm.sh/docs/) to learn how to run Helm with custom options using `--set` or `values.yaml`

**Feature Flags:**

Crossplane introduces new features behind feature flags. By default alpha features are off. Crossplane enables beta features by default. To enable a feature flag, set the `args` value in the Helm chart. Available feature flags can be directly found by running `crossplane core start --help`, or by looking at the feature flags table in the Crossplane documentation.

Set these flags either in the `values.yaml` file or at install time using the `--set` flag, for example:

```bash
--set args='{"--enable-composition-functions","--enable-composition-webhook-schema-validation"}'
```

#### Install Pre-Release Crossplane Versions

Install pre-release versions of Crossplane from the master Crossplane Helm channel.

**Warning:** Versions in the master channel are under active development and may be unstable. Don't use Crossplane master releases in production. Only use stable channel. Only use master for testing and development.

**Add the Crossplane Master Helm Repository:**

Add the Crossplane repository with the `helm repo add` command:

```bash
helm repo add crossplane-master https://charts.crossplane.io/master/
```

Update the local Helm chart cache with `helm repo update`:

```bash
helm repo update
```

**Install the Crossplane Master Helm Chart:**

Install the Crossplane Helm chart from the master channel with `helm install`. Use the `--devel` flag to install the latest pre-release version:

```bash
helm install crossplane \
  --namespace crossplane-system \
  --create-namespace crossplane-master/crossplane \
  --devel
```

#### Build and Install from Source

Building Crossplane from the source code gives you complete control over the build and installation process. Full instructions for this advanced installation path are in the [install from source code guide](https://docs.crossplane.io/latest/software/install/#build-and-install-from-source).

### Harbor Installation

This section describes how to perform a new installation of Harbor.

**Note:** If you are upgrading from a previous version of Harbor, you might need to update the configuration file and migrate your data to fit the database schema of the later version. For information about upgrading, see [Upgrading Harbor](https://goharbor.io/docs/latest/administration/upgrade/).

**Testing Harbor:**

Before you install Harbor, you can test the latest version of Harbor on a demo environment maintained by the Harbor team. For information, see [Test Harbor with the Demo Server](https://goharbor.io/docs/latest/install-config/test-harbor-with-demo-server/).

**Harbor Integrations:**

Harbor supports integration with different 3rd-party replication adapters for replicating data, OIDC adapters for authN/authZ, and scanner adapters for vulnerability scanning of container images. For information about the supported adapters, see the [Harbor Compatibility List](https://goharbor.io/docs/latest/install-config/harbor-compatibility-list/).

#### Installation Process

The standard Harbor installation process involves the following stages:

1. **Make sure that your target host meets the Harbor Installation Prerequisites**
2. **Download the Harbor Installer**
3. **Configure HTTPS Access to Harbor**
4. **Configure the Harbor YML File**
5. **Configure Enabling Internal TLS**
6. **Run the Installer Script**

If installation fails, see [Troubleshooting Harbor Installation](https://goharbor.io/docs/latest/install-config/troubleshooting-installation/).

#### Deploy Harbor on Kubernetes

You can also use Helm to install Harbor on a Kubernetes cluster, to make Harbor highly available. For information about installing Harbor with Helm on a Kubernetes cluster, see [Deploying Harbor with High Availability via Helm](https://goharbor.io/docs/latest/install-config/harbor-ha-helm-install/).

**Recommended Approach for Platform Demo:**

For this platform engineering demo, we recommend using the Helm chart installation method for Kubernetes deployment, as it provides:

- High availability
- Better integration with GitOps (Argo CD)
- Easier configuration management
- Production-ready deployment

**Example Helm Installation:**

```bash
helm repo add harbor https://helm.goharbor.io
helm repo update
helm install harbor harbor/harbor \
  --namespace harbor \
  --create-namespace \
  --set externalURL=https://harbor.example.com \
  --set expose.type=ingress \
  --set expose.ingress.hosts.core=harbor.example.com
```

#### Post-Installation Configuration

For information about how to manage your deployed Harbor instance, see [Reconfigure Harbor and Manage the Harbor Lifecycle](https://goharbor.io/docs/latest/administration/manage-lifecycle/).

**Token Service Configuration:**

By default, Harbor uses its own private key and certificate to authenticate with Docker. For information about how to optionally customize your configuration to use your own key and certificate, see [Customize the Harbor Token Service](https://goharbor.io/docs/latest/administration/configure-token-service/).

**System Configuration:**

After installation, log into your Harbor via the web console to configure the instance under 'configuration'. Harbor also provides a command line interface (CLI) that allows you to [Configure Harbor System Settings at the Command Line](https://goharbor.io/docs/latest/administration/configure-system-settings/).

#### Harbor Components

The table below lists some of the key components that are deployed when you deploy Harbor:

| Component | Version |
|-----------|---------|
| Postgresql | 15.12 |
| Redis | 7.2.6 |
| Beego | 2.3.4 |
| Distribution/Distribution | 2.8.3 |
| Helm | 2.9.1 |
| Swagger-ui | 5.9.1 |

**Note:** The postgresql and redis version might be updated in minor patches.

**Additional Resources:**

- [Test Harbor with the Demo Server](https://goharbor.io/docs/latest/install-config/test-harbor-with-demo-server/)
- [Harbor Compatibility List](https://goharbor.io/docs/latest/install-config/harbor-compatibility-list/)
- [Harbor Installation Prerequisites](https://goharbor.io/docs/latest/install-config/installation-prereqs/)
- [Download the Harbor Installer](https://goharbor.io/docs/latest/install-config/download-installer/)
- [Configure HTTPS Access to Harbor](https://goharbor.io/docs/latest/install-config/configure-https/)
- [Configure Internal TLS communication between Harbor Component](https://goharbor.io/docs/latest/install-config/configure-internal-tls/)
- [Configure the Harbor YML File](https://goharbor.io/docs/latest/install-config/configure-yml-file/)
- [Run the Installer Script](https://goharbor.io/docs/latest/install-config/run-installer-script/)
- [Deploying Harbor with High Availability via Helm](https://goharbor.io/docs/latest/install-config/harbor-ha-helm-install/)
- [Troubleshooting Harbor Installation](https://goharbor.io/docs/latest/install-config/troubleshooting-installation/)
- [Reconfigure Harbor and Manage the Harbor Lifecycle](https://goharbor.io/docs/latest/administration/manage-lifecycle/)
- [Customize the Harbor Token Service](https://goharbor.io/docs/latest/administration/configure-token-service/)
- [Harbor Configuration](https://goharbor.io/docs/latest/administration/configuration/)

#### Harbor Helm Chart Configuration

The Harbor Helm chart provides extensive configuration options for customizing your Harbor deployment. This section covers the key configuration parameters.

**Repository Information:**

- **Helm Repository**: `https://helm.goharbor.io`
- **Chart Name**: `harbor/harbor`
- **Note**: The master branch is in heavy development, please use stable versions instead

**Prerequisites:**

- Kubernetes cluster 1.20+
- Helm v3.2.0+

**Installation:**

```bash
helm repo add harbor https://helm.goharbor.io
helm repo update
helm install my-release harbor/harbor
```

**Uninstallation:**

```bash
helm uninstall my-release
```

**Configuration Methods:**

The following items can be set via `--set` flag during installation or configured by editing the `values.yaml` directly (need to download the chart first).

**Key Configuration Areas:**

1. **Expose Configuration**: How to expose the Harbor service (Ingress, ClusterIP, NodePort, LoadBalancer, Gateway APIs)
2. **Internal TLS**: Enable TLS for components (core, jobservice, portal, registry, trivy)
3. **IPFamily**: IPv4/IPv6 configuration
4. **Persistence**: Data persistence configuration for registry, jobservice, database, redis, trivy
5. **General Settings**: External URL, admin password, secrets, proxy settings
6. **Component Configuration**: Nginx, Portal, Core, Jobservice, Registry, Trivy
7. **Database Configuration**: Internal or external PostgreSQL
8. **Redis Configuration**: Internal or external Redis
9. **Metrics**: Prometheus metrics configuration
10. **Trace**: Distributed tracing configuration (Jaeger or OpenTelemetry)
11. **Cache**: Cache layer configuration

**Important Configuration Parameters:**

| Category | Parameter | Description | Default |
|----------|-----------|-------------|---------|
| **Expose** | `expose.type` | How to expose service: ingress, clusterIP, nodePort, loadBalancer | ingress |
| **Expose** | `expose.tls.enabled` | Enable TLS or not | true |
| **Expose** | `expose.tls.certSource` | TLS certificate source: auto, secret, none | auto |
| **Expose** | `expose.ingress.hosts.core` | Host of Harbor core service | core.harbor.domain |
| **General** | `externalURL` | External URL for Harbor core service | https://core.harbor.domain |
| **General** | `harborAdminPassword` | Initial password of Harbor admin | Harbor12345 |
| **General** | `secretKey` | Key used for encryption (must be 16 chars) | not-a-secure-key |
| **Persistence** | `persistence.enabled` | Enable data persistence | true |
| **Persistence** | `persistence.resourcePolicy` | PVC retention policy: keep or empty | keep |
| **Database** | `database.type` | Database type: internal or external | internal |
| **Redis** | `redis.type` | Redis type: internal or external | internal |
| **Trivy** | `trivy.enabled` | Enable Trivy scanner | true |

**Configure How to Expose Harbor Service:**

- **Ingress**: The ingress controller must be installed. Note: if TLS is disabled, the port must be included when pulling/pushing images.
- **ClusterIP**: Exposes the service on a cluster-internal IP (only reachable from within cluster)
- **NodePort**: Exposes the service on each Node's IP at a static port
- **LoadBalancer**: Exposes the service externally using a cloud provider's load balancer
- **Gateway APIs**: Exposes the service using gateway-api CRDs using HTTPRoute (requires v1.0.0+)

**Configure the External URL:**

The external URL for Harbor core service is used to:
- Populate the docker/helm commands showed on portal
- Populate the token service URL returned to docker client

Format: `protocol://domain[:port]`. Usually:
- If service exposed via Ingress: domain should be `expose.ingress.hosts.core`
- If service exposed via ClusterIP: domain should be `expose.clusterIP.name`
- If service exposed via NodePort: domain should be the IP address of one Kubernetes node
- If service exposed via LoadBalancer: set domain as your own domain name and add a CNAME record

**Configure How to Persist Data:**

- **Disable**: Data does not survive pod termination
- **Persistent Volume Claim (default)**: A default StorageClass is needed. Specify another StorageClass in `storageClass` or set `existingClaim` if you already have existing persistent volumes
- **External Storage (only for images and charts)**: Supported storages: azure, gcs, s3, swift, oss

**Harbor Kubernetes Version Compatibility Matrix:**

The following is a list of tested Kubernetes versions for each Harbor version. Generally, Harbor supports Kubernetes version above v1.20+. However, only 3 Kubernetes minor versions are tested for each Harbor minor release.

| Harbor-Helm Version | Harbor App Version | Tested on Kubernetes version |
|---------------------|-------------------|------------------------------|
| 1.18 | v2.14 | 1.34.0, 1.33.4, 1.32.8 |
| 1.17 | v2.13 | 1.31.1, 1.30.4, 1.29.8 |
| 1.16 | v2.12 | 1.31.1, 1.30.4, 1.29.8 |

**Example Custom Values File:**

For GitOps deployments, create a `harbor-values.yaml` file:

```yaml
externalURL: https://harbor.example.com

expose:
  type: ingress
  tls:
    enabled: true
    certSource: auto
  ingress:
    hosts:
      core: harbor.example.com
    className: traefik
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"

harborAdminPassword: "env://HARBOR_ADMIN_PASSWORD"  # From External Secrets

persistence:
  enabled: true
  resourcePolicy: keep
  persistentVolumeClaim:
    registry:
      size: 50Gi
      storageClass: fast-ssd

database:
  type: external
  external:
    host: platform-postgres.platform.svc.cluster.local
    port: 5432
    username: "env://HARBOR_DB_USER"  # From External Secrets
    password: "env://HARBOR_DB_PASSWORD"  # From External Secrets
    coreDatabase: harbor
    existingSecret: harbor-db-secret
    sslmode: require

redis:
  type: external
  external:
    addr: redis.platform.svc.cluster.local:6379
    existingSecret: harbor-redis-secret

oidc:
  name: authentik
  endpoint: https://authentik.company/application/o/harbor
  clientID: "env://HARBOR_OIDC_CLIENT_ID"  # From External Secrets
  clientSecret: "env://HARBOR_OIDC_CLIENT_SECRET"  # From External Secrets
  scope: "openid,profile,email,offline_access"
  usernameClaim: "preferred_username"

trivy:
  enabled: true
  severity: UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL

metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```

**Additional Resources:**

- [Harbor Helm Chart Repository](https://github.com/goharbor/harbor-helm)
- [Harbor Helm Chart README](https://github.com/goharbor/harbor-helm/blob/main/README.md)
- [High Availability Deployment Guide](https://goharbor.io/docs/latest/install-config/harbor-ha-helm-install/)
- [Upgrade Guide](https://goharbor.io/docs/latest/administration/upgrade/)

### Phase 3: Security Technologies

1. **Vault** (existing - add Argo CD deployment)
   - Use Context7 MCP to get latest version
   - Create `argocd/app-of-apps/apps/security/vault.yaml`
   - Configure for secrets management
   - See Argo CD Application manifest below

2. **External Secrets**
   - Use Context7 MCP to get latest version
   - Create `argocd/app-of-apps/apps/security/external-secrets.yaml`
   - Configure Vault backend integration
   - See Argo CD Application manifest below

3. **Authentik** (MUST be installed before Backstage)
   - Use Context7 MCP to get latest version
   - Create `argocd/app-of-apps/apps/security/authentik.yaml`
   - Configure PostgreSQL connection to Zalando Postgres Operator cluster:
     - Host: `platform-postgres.platform.svc.cluster.local`
     - Database: `authentik` (created by operator)
     - User: `zalando` (created by operator)
     - Use External Secrets for database credentials (from Vault)
     - Configure connection settings (see PostgreSQL Configuration section)
     - Set up connection pooling if using PgBouncer/PgPool
   - Configure OIDC/OAuth2 providers
   - Set up integration with Argo CD and Backstage (OAuth2 Proxy)
   - Complete initial setup and configure OAuth2/OIDC providers
   - **Important**: Authentik must be fully configured and accessible before deploying Backstage

#### Vault Argo CD Application Manifest

Create an Argo CD Application manifest for Vault:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vault
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app.kubernetes.io/instance: security
    app.kubernetes.io/name: vault
spec:
  destination:
    namespace: vault
    server: https://kubernetes.default.svc
  project: security
  source:
    repoURL: https://helm.releases.hashicorp.com
    chart: vault
    targetRevision: <latest-version>  # Use Context7 MCP to get latest version
    helm:
      valueFiles:
        - $values/vault-values.yaml
      values: |
        server:
          ha:
            enabled: true
            replicas: 3
          dataStorage:
            enabled: true
            size: 10Gi
            storageClass: fast-ssd
          auditStorage:
            enabled: true
            size: 10Gi
            storageClass: fast-ssd
        ui:
          enabled: true
        ingress:
          enabled: true
          ingressClassName: traefik
          hosts:
            - host: vault.example.com
              paths:
                - /
          tls:
            - secretName: vault-tls
              hosts:
                - vault.example.com
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
      namespace: vault
      jsonPointers:
        - /data
    - group: ""
      kind: ConfigMap
      namespace: vault
      jsonPointers:
        - /data
    - group: ""
      kind: PersistentVolumeClaim
      namespace: vault
      jsonPointers:
        - /status
```

**Key Configuration Points:**

- **High Availability**: Enable HA mode with 3 replicas for production
- **Storage**: Configure persistent storage for data and audit logs
- **UI**: Enable Vault UI for easier management
- **Ingress**: Configure Traefik ingress for external access
- **TLS**: Use cert-manager or manual TLS certificates

#### External Secrets Operator Argo CD Application Manifest

Create an Argo CD Application manifest for External Secrets Operator:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: external-secrets
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app.kubernetes.io/instance: security
    app.kubernetes.io/name: external-secrets
spec:
  destination:
    namespace: external-secrets-system
    server: https://kubernetes.default.svc
  project: security
  source:
    repoURL: https://charts.external-secrets.io
    chart: external-secrets
    targetRevision: <latest-version>  # Use Context7 MCP to get latest version
    helm:
      valueFiles:
        - $values/external-secrets-values.yaml
      values: |
        installCRDs: true
        replicaCount: 2
        webhook:
          replicaCount: 2
        certController:
          replicaCount: 2
        securityContext:
          runAsNonRoot: true
          runAsUser: 65534
          fsGroup: 65534
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 128Mi
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
      namespace: external-secrets-system
      jsonPointers:
        - /data
    - group: ""
      kind: ConfigMap
      namespace: external-secrets-system
      jsonPointers:
        - /data
```

**Key Configuration Points:**

- **CRDs**: Install CRDs automatically with `installCRDs: true`
- **High Availability**: Set replica counts for all components
- **Security**: Use non-root security context
- **Resources**: Configure appropriate resource limits and requests

**Vault SecretStore Configuration:**

After deploying External Secrets, create a SecretStore for Vault:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: default
spec:
  provider:
    vault:
      server: http://vault.vault.svc.cluster.local:8200
      path: secret
      version: v2
      auth:
        kubernetes:
          mountPath: kubernetes
          role: external-secrets
          serviceAccountRef:
            name: external-secrets-vault
            namespace: external-secrets-system
```

### Phase 4: Backstage Deployment (After Authentik)

1. **Backstage**
   - Use Context7 MCP to get latest Backstage version and plugin versions
   - Create `argocd/app-of-apps/apps/automation/backstage.yaml`
   - Build process:
     - Create Dockerfile for Backstage app
     - Argo Workflow will build image using `yarn build-image --tag <harbor-registry>/backstage:<version>`
     - Push image to Harbor registry
     - Deploy via Argo CD using the Harbor image
   - Configuration:
     - PostgreSQL database connection to Zalando Postgres Operator cluster:
       - Host: `platform-postgres.platform.svc.cluster.local`
       - Database: `backstage` (created by operator)
       - User: `zalando` (created by operator)
     - Use External Secrets for database credentials (from Vault)
     - OAuth2 Proxy provider integration with Authentik (Authentik must be ready)
     - Kubernetes deployment with proper health checks
     - Plugins:
       - Crossplane Resources Frontend (`@terasky/backstage-plugin-crossplane-resources`)
       - Crossplane Resources Backend (`@terasky/backstage-plugin-crossplane-resources-backend`)
       - Crossplane Common (`@terasky/backstage-plugin-crossplane-common`)
       - Kubernetes Ingestor (from TeraSky plugins)
       - Additional plugins as needed
   - Authentication:
     - Configure OAuth2 Proxy provider in `app-config.yaml`
     - Use Authentik as the OIDC provider (must be configured first)
     - Set up `forwardedUserMatchingUserEntityName` resolver
     - Install `@backstage/plugin-auth-backend-module-oauth2-proxy-provider`
   - See Argo CD Application manifest below

#### OAuth2 Proxy Deployment

OAuth2 Proxy is used as a Traefik middleware to authenticate requests to Backstage and other applications.

1. **Deploy OAuth2 Proxy:**
   - Create `argocd/app-of-apps/apps/security/oauth2-proxy.yaml`
   - See OAuth2 Proxy Argo CD Application manifest below

2. **Create External Secrets for OAuth2 Proxy:**
   ```yaml
   apiVersion: external-secrets.io/v1beta1
   kind: ExternalSecret
   metadata:
     name: oauth2-proxy-credentials
     namespace: oauth2-proxy
   spec:
     secretStoreRef:
       name: vault-backend
       kind: SecretStore
     target:
       name: oauth2-proxy-credentials
       creationPolicy: Owner
     data:
       - secretKey: OAUTH2_PROXY_CLIENT_ID
         remoteRef:
           key: platform/oauth2-proxy/client-id
       - secretKey: OAUTH2_PROXY_CLIENT_SECRET
         remoteRef:
           key: platform/oauth2-proxy/client-secret
       - secretKey: OAUTH2_PROXY_COOKIE_SECRET
         remoteRef:
           key: platform/oauth2-proxy/cookie-secret
   ```

3. **Configure Authentik OAuth2 Provider:**
   - In Authentik, create an OAuth2/OpenID Provider
   - Redirect URI: `https://oauth2-proxy.oauth2-proxy.svc.cluster.local:4180/oauth2/callback`
   - Client ID and Secret: Store in Vault (used by External Secrets above)
   - Scopes: `openid`, `profile`, `email`

4. **Create Traefik Middleware:**
   ```yaml
   apiVersion: traefik.io/v1alpha1
   kind: Middleware
   metadata:
     name: oauth2-proxy
     namespace: oauth2-proxy
   spec:
     forwardAuth:
       address: http://oauth2-proxy.oauth2-proxy.svc.cluster.local:4180
       authResponseHeaders:
         - X-Forwarded-User
         - X-Forwarded-Email
         - X-Forwarded-Preferred-Username
       trustForwardHeader: true
   ```

5. **Verify OAuth2 Proxy Deployment:**
   ```bash
   # Check OAuth2 Proxy pods
   kubectl get pods -n oauth2-proxy -l app.kubernetes.io/name=oauth2-proxy
   
   # Check OAuth2 Proxy service
   kubectl get svc -n oauth2-proxy oauth2-proxy
   
   # Test OAuth2 Proxy (from within cluster)
   kubectl run -it --rm oauth2-test --image=curlimages/curl --restart=Never -n oauth2-proxy -- \
     curl -v http://oauth2-proxy.oauth2-proxy.svc.cluster.local:4180/oauth2/start
   ```

**OAuth2 Proxy Connection Details:**
- **Service**: `oauth2-proxy.oauth2-proxy.svc.cluster.local:4180`
- **Traefik Middleware**: `oauth2-proxy` (in `oauth2-proxy` namespace)
- **Credentials**: Managed via External Secrets from Vault

#### OAuth2 Proxy Argo CD Application Manifest

The OAuth2 Proxy deployment manifest is located at `argocd/app-of-apps/apps/security/oauth2-proxy.yaml`. See the file for complete configuration.

**Key Configuration Points:**

- **OIDC Provider**: Configured to use Authentik
- **High Availability**: 2 replicas for production
- **Traefik Integration**: Used as middleware, not ingress
- **User Headers**: Passes user information to upstream applications
- **Credentials**: Managed via External Secrets from Vault

#### Backstage Argo CD Application Manifest

Backstage is typically deployed as a Kubernetes Deployment using a custom-built Docker image. Create an Argo CD Application manifest:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: backstage
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app.kubernetes.io/instance: automation
    app.kubernetes.io/name: backstage
spec:
  destination:
    namespace: backstage
    server: https://kubernetes.default.svc
  project: automation
  source:
    repoURL: https://github.com/your-org/platform.git
    targetRevision: HEAD
    path: argocd/app-of-apps/apps/automation/backstage
    kustomize:
      images:
        - name: backstage
          newName: harbor.example.com
          newTag: <version>  # Updated by Argo Workflows
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
      namespace: backstage
      jsonPointers:
        - /data
    - group: ""
      kind: ConfigMap
      namespace: backstage
      jsonPointers:
        - /data
```

**Backstage Kubernetes Deployment Manifest:**

Create the actual Backstage deployment in `argocd/app-of-apps/apps/automation/backstage/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backstage
  namespace: backstage
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backstage
  template:
    metadata:
      labels:
        app: backstage
    spec:
      containers:
      - name: backstage
        image: ${HARBOR_REGISTRY}/backstage:<version>
        imagePullPolicy: Always
        ports:
        - containerPort: 7007
          name: http
        envFrom:
        - configMapRef:
            name: platform-config
        env:
        - name: NODE_ENV
          value: "production"
        - name: POSTGRES_HOST
          value: "platform-postgres.platform.svc.cluster.local"
        - name: POSTGRES_PORT
          value: "5432"
        - name: POSTGRES_USER
          value: "zalando"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: backstage-postgres
              key: db-password
        - name: AUTH_OAUTH2_PROXY_PROVIDER_RESOLVER
          value: "forwardedUserMatchingUserEntityName"
        volumeMounts:
        - name: app-config
          mountPath: /app-config.yaml
          subPath: app-config.yaml
      volumes:
      - name: app-config
        configMap:
          name: backstage-app-config
        resources:
          limits:
            cpu: 2000m
            memory: 2Gi
          requests:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /healthcheck
            port: 7007
          initialDelaySeconds: 60
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /healthcheck
            port: 7007
          initialDelaySeconds: 30
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: backstage
  namespace: backstage
spec:
  selector:
    app: backstage
  ports:
  - port: 80
    targetPort: 7007
    protocol: TCP
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: backstage
  namespace: backstage
spec:
  entryPoints:
    - websecure
  routes:
    - kind: Rule
      match: Host(`backstage.example.com`)
      priority: 10
      services:
        - name: backstage
          port: 80
      middlewares:
        - name: oauth2-proxy
          namespace: backstage
  tls:
    certResolver: default
```

**External Secret for Database Password:**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: backstage-postgres
  namespace: backstage
spec:
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: backstage-postgres
    creationPolicy: Owner
  data:
    - secretKey: db-password
      remoteRef:
        key: platform/backstage/db-password
```

**Key Configuration Points:**

- **PostgreSQL Backend**: Use shared PostgreSQL cluster
- **High Availability**: Set replica count for production
- **Health Checks**: Configure liveness and readiness probes
- **OAuth2 Proxy**: Use Traefik middleware for authentication
- **Image Updates**: Argo Workflows updates image tag in Git
- **Database Credentials**: Use External Secrets from Vault
- **Ingress**: Configure Traefik IngressRoute for external access

### Phase 5: Observability Stack

1. **Grafana Alloy** (telemetry collector)
   - Deploy using Kubernetes Monitoring Helm chart via Argo CD
   - Configure to send metrics, logs, and traces to Grafana Cloud
   - Enable Fleet Management for centralized configuration
   - See detailed configuration below

#### Configure Grafana Alloy

**Overview**

Grafana Alloy is a telemetry collector that collects metrics, logs, and traces from your Kubernetes cluster and forwards them to Grafana Cloud. It replaces Grafana Agent and provides better performance and features.

**Prerequisites**

- Kubernetes cluster with kubectl and Helm access
- Grafana Cloud account with:
  - Prometheus metrics service endpoint
  - Loki logging service endpoint
  - Tempo tracing service endpoint
  - OTLP gateway endpoint
  - Fleet Management endpoint
- Access policy token with appropriate scopes:
  - `metrics:write`
  - `logs:write`
  - `traces:write`
  - `profiles:write`
  - `metrics:read`
  - `fleet-management:read`

**Features**

The Kubernetes Monitoring Helm chart provides:

- **Cluster Metrics**: Kubernetes cluster metrics collection
- **Cost Metrics**: OpenCost integration for cost tracking
- **Energy Metrics**: Kepler integration for energy consumption tracking
- **Cluster Events**: Kubernetes event collection
- **Pod Logs**: Container log collection
- **Application Observability**: OTLP receiver for application telemetry
- **Fleet Management**: Centralized configuration management

**Argo CD Application Manifest**

Create an Argo CD Application manifest for Grafana Alloy:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: grafana-alloy
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app.kubernetes.io/instance: observability
    app.kubernetes.io/name: grafana-alloy
spec:
  destination:
    namespace: default
    server: https://kubernetes.default.svc
  project: observability
  source:
    repoURL: https://grafana.github.io/helm-charts
    chart: k8s-monitoring
    targetRevision: <latest-version>
    helm:
      valueFiles:
        - $values/alloy-values.yaml
      values: |
        cluster:
          name: <cluster-name>

        destinations:
          - name: grafana-cloud-metrics
            type: prometheus
            url: https://prometheus-prod-56-prod-us-east-2.grafana.net./api/prom/push
            auth:
              type: basic
              username: "<metrics-username>"
              password: "env://GRAFANA_CLOUD_METRICS_TOKEN"

          - name: grafana-cloud-logs
            type: loki
            url: https://logs-prod-036.grafana.net./loki/api/v1/push
            auth:
              type: basic
              username: "<logs-username>"
              password: "env://GRAFANA_CLOUD_LOGS_TOKEN"

          - name: gc-otlp-endpoint
            type: otlp
            url: https://otlp-gateway-prod-us-east-2.grafana.net./otlp
            protocol: http
            auth:
              type: basic
              username: "<otlp-username>"
              password: "env://GRAFANA_CLOUD_OTLP_TOKEN"
            metrics:
              enabled: true
            logs:
              enabled: true
            traces:
              enabled: true

        clusterMetrics:
          enabled: true
          opencost:
            enabled: true
            metricsSource: grafana-cloud-metrics
            opencost:
              exporter:
                defaultClusterId: <cluster-name>
              prometheus:
                existingSecretName: grafana-cloud-metrics-grafana-k8s-monitoring
                external:
                  url: https://prometheus-prod-56-prod-us-east-2.grafana.net./api/prom
          kepler:
            enabled: true

        clusterEvents:
          enabled: true

        podLogs:
          enabled: true

        applicationObservability:
          enabled: true
          receivers:
            otlp:
              grpc:
                enabled: true
                port: 4317
              http:
                enabled: true
                port: 4318
            zipkin:
              enabled: true
              port: 9411

        alloy-metrics:
          enabled: true
          alloy:
            extraEnv:
              - name: GCLOUD_RW_API_KEY
                valueFrom:
                  secretKeyRef:
                    name: alloy-metrics-remote-cfg-grafana-k8s-monitoring
                    key: password
              - name: CLUSTER_NAME
                value: <cluster-name>
              - name: NAMESPACE
                valueFrom:
                  fieldRef:
                    fieldPath: metadata.namespace
              - name: POD_NAME
                valueFrom:
                  fieldRef:
                    fieldPath: metadata.name
              - name: GCLOUD_FM_COLLECTOR_ID
                value: grafana-k8s-monitoring-$(CLUSTER_NAME)-$(NAMESPACE)-$(POD_NAME)
          remoteConfig:
            enabled: true
            url: https://fleet-management-prod-008.grafana.net
            auth:
              type: basic
              username: "<fleet-username>"
              password: "env://GRAFANA_CLOUD_FLEET_TOKEN"

        alloy-singleton:
          enabled: true
          alloy:
            extraEnv:
              - name: GCLOUD_RW_API_KEY
                valueFrom:
                  secretKeyRef:
                    name: alloy-singleton-remote-cfg-grafana-k8s-monitoring
                    key: password
              - name: CLUSTER_NAME
                value: <cluster-name>
              - name: NAMESPACE
                valueFrom:
                  fieldRef:
                    fieldPath: metadata.namespace
              - name: POD_NAME
                valueFrom:
                  fieldRef:
                    fieldPath: metadata.name
              - name: GCLOUD_FM_COLLECTOR_ID
                value: grafana-k8s-monitoring-$(CLUSTER_NAME)-$(NAMESPACE)-$(POD_NAME)
          remoteConfig:
            enabled: true
            url: https://fleet-management-prod-008.grafana.net
            auth:
              type: basic
              username: "<fleet-username>"
              password: "env://GRAFANA_CLOUD_FLEET_TOKEN"

        alloy-logs:
          enabled: true
          alloy:
            extraEnv:
              - name: GCLOUD_RW_API_KEY
                valueFrom:
                  secretKeyRef:
                    name: alloy-logs-remote-cfg-grafana-k8s-monitoring
                    key: password
              - name: CLUSTER_NAME
                value: <cluster-name>
              - name: NAMESPACE
                valueFrom:
                  fieldRef:
                    fieldPath: metadata.namespace
              - name: POD_NAME
                valueFrom:
                  fieldRef:
                    fieldPath: metadata.name
              - name: NODE_NAME
                valueFrom:
                  fieldRef:
                    fieldPath: spec.nodeName
              - name: GCLOUD_FM_COLLECTOR_ID
                value: grafana-k8s-monitoring-$(CLUSTER_NAME)-$(NAMESPACE)-alloy-logs-$(NODE_NAME)
          remoteConfig:
            enabled: true
            url: https://fleet-management-prod-008.grafana.net
            auth:
              type: basic
              username: "<fleet-username>"
              password: "env://GRAFANA_CLOUD_FLEET_TOKEN"

        alloy-receiver:
          enabled: true
          alloy:
            extraPorts:
              - name: otlp-grpc
                port: 4317
                targetPort: 4317
                protocol: TCP
              - name: otlp-http
                port: 4318
                targetPort: 4318
                protocol: TCP
              - name: zipkin
                port: 9411
                targetPort: 9411
                protocol: TCP
            extraEnv:
              - name: GCLOUD_RW_API_KEY
                valueFrom:
                  secretKeyRef:
                    name: alloy-receiver-remote-cfg-grafana-k8s-monitoring
                    key: password
              - name: CLUSTER_NAME
                value: <cluster-name>
              - name: NAMESPACE
                valueFrom:
                  fieldRef:
                    fieldPath: metadata.namespace
              - name: POD_NAME
                valueFrom:
                  fieldRef:
                    fieldPath: metadata.name
              - name: NODE_NAME
                valueFrom:
                  fieldRef:
                    fieldPath: spec.nodeName
              - name: GCLOUD_FM_COLLECTOR_ID
                value: grafana-k8s-monitoring-$(CLUSTER_NAME)-$(NAMESPACE)-alloy-receiver-$(NODE_NAME)
          remoteConfig:
            enabled: true
            url: https://fleet-management-prod-008.grafana.net
            auth:
              type: basic
              username: "<fleet-username>"
              password: "env://GRAFANA_CLOUD_FLEET_TOKEN"
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
      namespace: default
      jsonPointers:
        - /data
```

**External Secrets Configuration**

Store Grafana Cloud tokens in Vault and use External Secrets Operator:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: grafana-cloud-metrics-token
  namespace: default
spec:
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: grafana-cloud-metrics-token
    creationPolicy: Owner
  data:
    - secretKey: token
      remoteRef:
        key: platform/grafana-cloud/metrics-token
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: grafana-cloud-logs-token
  namespace: default
spec:
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: grafana-cloud-logs-token
    creationPolicy: Owner
  data:
    - secretKey: token
      remoteRef:
        key: platform/grafana-cloud/logs-token
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: grafana-cloud-otlp-token
  namespace: default
spec:
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: grafana-cloud-otlp-token
    creationPolicy: Owner
  data:
    - secretKey: token
      remoteRef:
        key: platform/grafana-cloud/otlp-token
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: grafana-cloud-fleet-token
  namespace: default
spec:
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: grafana-cloud-fleet-token
    creationPolicy: Owner
  data:
    - secretKey: token
      remoteRef:
        key: platform/grafana-cloud/fleet-token
```

**Application Instrumentation Endpoints**

After deployment, configure your applications to send telemetry to:

- **OTLP/gRPC**: `http://grafana-k8s-monitoring-alloy-receiver.default.svc.cluster.local:4317`
- **OTLP/HTTP**: `http://grafana-k8s-monitoring-alloy-receiver.default.svc.cluster.local:4318`
- **Zipkin**: `grafana-k8s-monitoring-alloy-receiver.default.svc.cluster.local:9411`

**Key Points**

- **Fleet Management**: Enables centralized configuration management from Grafana Cloud
- **Remote Configuration**: Alloy collectors fetch configuration from Fleet Management
- **Multiple Collectors**: Deploys separate collectors for metrics, logs, and traces
- **Security**: Use External Secrets Operator with Vault for all tokens
- **Cluster Name**: Replace `<cluster-name>` with your actual cluster name
- **Token Management**: Store all Grafana Cloud tokens securely in Vault

**Additional Resources**

- [Grafana Alloy Documentation](https://grafana.com/docs/alloy/latest/)
- [Kubernetes Monitoring Helm Chart](https://github.com/grafana/helm-charts/tree/main/charts/k8s-monitoring)
- [Fleet Management](https://grafana.com/docs/grafana-cloud/fundamentals/fleet-management/)

### Phase 6: Integration & Workflows
1. Create Argo Workflow templates for:
   - Building container images (including Backstage)
   - Pushing to Harbor registry
   - Triggering Argo CD syncs
   - Backstage-specific workflow:
     - Build Backstage app: `yarn install && yarn build-image --tag <harbor>/backstage:<version>`
     - Push to Harbor
     - Update Argo CD Application manifest with new image tag

2. Configure GitHub integration:
   - GitHub Actions or webhooks to trigger Argo Workflows
   - GitHub authentication for Backstage catalog

3. Set up authentication flows:
   - Authentik → OAuth2 Proxy → Backstage
   - Authentik → Argo CD (OIDC)

4. Configure Backstage integrations:
   - GitHub integration for catalog entities
   - Kubernetes integration for resource visualization
   - Crossplane integration for infrastructure visibility

## Key Configuration Patterns

### Application Manifest Template

Each technology should follow this pattern (versions determined via Context7 MCP):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <technology-name>
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app.kubernetes.io/instance: <category>
    app.kubernetes.io/name: <technology-name>
spec:
  destination:
    namespace: <technology-namespace>
    server: https://kubernetes.default.svc
  project: <category>
  source:
    repoURL: <helm-repo-or-git-repo>
    chart: <chart-name>  # if Helm
    targetRevision: <version>  # From Context7 MCP
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
  ignoreDifferences:
    - group: ""
      kind: Secret
      namespace: <technology-namespace>
      jsonPointers:
        - /data
    - group: ""
      kind: ConfigMap
      namespace: <technology-namespace>
      jsonPointers:
        - /data
```

### Backstage Build and Deployment Pattern

1. **Build Process** (via Argo Workflows):
   ```yaml
   # Argo Workflow template
   - name: build-backstage
     container:
       image: node:20
       command: [sh, -c]
       args:
         - |
           yarn install
           yarn build-image --tag harbor.example.com/backstage:{{workflow.parameters.version}}
   - name: push-to-harbor
     container:
       image: harbor.example.com/backstage:{{workflow.parameters.version}}
       # Push to Harbor
   ```

2. **Deployment Configuration**:
   - PostgreSQL deployment (separate or managed)
   - Backstage deployment using Harbor image
   - OAuth2 Proxy sidecar or ingress annotation
   - Environment variables from External Secrets (Vault)

3. **Backstage app-config.yaml**:
   ```yaml
   auth:
     providers:
       oauth2Proxy:
         signIn:
           resolvers:
             - resolver: forwardedUserMatchingUserEntityName
   backend:
     database:
       client: pg
       connection:
         host: ${POSTGRES_HOST}
         port: ${POSTGRES_PORT}
         user: ${POSTGRES_USER}
         password: ${POSTGRES_PASSWORD}
   ```

4. **Plugin Installation**:
   - Frontend plugins: `yarn --cwd packages/app add @terasky/backstage-plugin-crossplane-resources`
   - Backend plugins: `yarn --cwd packages/backend add @terasky/backstage-plugin-crossplane-resources-backend`
   - Common packages: Automatically included as dependencies

#### Crossplane Backstage Plugins

The platform uses TeraSky's Crossplane plugins for Backstage to provide visibility into Crossplane infrastructure resources. These plugins integrate with the Kubernetes Ingestor to automatically discover and display Crossplane resources.

**Crossplane Resources Frontend** (`@terasky/backstage-plugin-crossplane-resources`):

- **Purpose**: Frontend plugin that provides visibility into Crossplane claim, composite resource, and managed resources associated with a component
- **Features**:
  - Displays general data about Crossplane resources
  - YAML viewer for each resource with ability to:
    - Copy to clipboard
    - Download YAML file
  - View events related to specific resources
  - Graph view of resources related to a claim
- **Dependencies**: 
  - Relies heavily on system-generated annotations from the Kubernetes Ingestor
  - Technically does not require it if all needed annotations are added manually
- **Installation**: `yarn --cwd packages/app add @terasky/backstage-plugin-crossplane-resources`

**Crossplane Resources Backend** (`@terasky/backstage-plugin-crossplane-resources-backend`):

- **Purpose**: Backend plugin that implements the permission framework elements for the Crossplane frontend plugin and provides necessary backend services
- **Features**:
  - Implements Backstage permission framework for Crossplane resources
  - Provides API endpoints for the frontend
  - Enables access control and policy enforcement
- **Installation**: `yarn --cwd packages/backend add @terasky/backstage-plugin-crossplane-resources-backend`

**Crossplane Common** (`@terasky/backstage-plugin-crossplane-common`):

- **Purpose**: Shared common library between the frontend and backend Crossplane plugins where the permission definitions reside
- **Note**: This package is not added into a Backstage instance directly, rather it is a dependency of both the frontend and backend plugins
- **Installation**: Automatically included as a dependency when installing the frontend or backend plugins

**Integration with Kubernetes Ingestor:**

The Crossplane plugins work best when used with the Kubernetes Ingestor plugin, which automatically:
- Discovers Crossplane claims and composite resources in the cluster
- Creates Backstage catalog entities from Kubernetes resources
- Adds necessary annotations for the Crossplane plugins to function
- Supports auto-ingestion of all Crossplane claims and KRO instances as components

**Configuration:**

After installing the plugins, configure them in your Backstage `app-config.yaml`:

```yaml
integrations:
  kubernetes:
    # Kubernetes cluster configuration for Crossplane resource discovery
    serviceLocatorMethod:
      type: 'multiTenant'
    clusterLocatorMethods:
      - type: 'config'
        clusters:
          - url: https://kubernetes.default.svc
            name: default
            authProvider: 'serviceAccount'
            skipTLSVerify: false
```

**Usage:**

Once configured, developers can:
- View Crossplane claims associated with their components
- See composite resources and managed resources
- Inspect YAML configurations
- View resource events and status
- Understand resource relationships through the graph view
- Manage infrastructure as code through Backstage UI

### Authentik Kubernetes Installation and Configuration

Authentik is installed on Kubernetes using the Helm chart. Follow these steps for proper configuration:

#### Requirements

- Kubernetes cluster
- Helm 3.x
- Traefik ingress controller (or nginx/kong)

#### Generate Passwords

Before installation, generate secure passwords for the database and cache:

```bash
# Option 1: Using pwgen
pwgen -s 50 1

# Option 2: Using openssl
openssl rand 60 | base64 -w 0
```

#### Create Values File

Create a `values.yaml` file with minimum required settings:

```yaml
authentik:
  secret_key: "PleaseGenerateASecureKey"
  # This sends anonymous usage-data, stack traces on errors and
  # performance data to sentry.io, and is fully opt-in
  error_reporting:
    enabled: true
  postgresql:
    password: "ThisIsNotASecurePassword"

server:
  ingress:
    # Specify kubernetes ingress controller class name
    ingressClassName: traefik  # or nginx | kong
    enabled: true
    hosts:
      - authentik.domain.tld

postgresql:
  enabled: true
  auth:
    password: "ThisIsNotASecurePassword"
```

**Note**: For production, use External Secrets Operator to manage passwords from Vault instead of hardcoding them in values.yaml.

#### Install Authentik Helm Chart

```bash
helm repo add authentik https://charts.goauthentik.io
helm repo update
helm upgrade --install authentik authentik/authentik -f values.yaml
```

During installation, database migrations are applied automatically on startup.

#### Accessing Authentik

After installation, access Authentik at:
```
https://<ingress-host-name>/if/flow/initial-setup/
```

**Important**: The trailing forward slash `/` is required. Without it, you will get a Not Found error.

At the initial setup URL, set a password for the default `akadmin` user.

#### Automated Installation (Skip Out-of-Box Experience)

To install authentik automatically (skipping the Out-of-box experience), you can use the following environment variables on the worker container:

**Environment Variables:**

- **AUTHENTIK_BOOTSTRAP_PASSWORD**: Configure the default password for the `akadmin` user. Only read on the first startup. Can be used for any flow executor.
- **AUTHENTIK_BOOTSTRAP_TOKEN**: Create a token for the default `akadmin` user. Only read on the first startup. The string you specify for this variable is the token key you can use to authenticate yourself to the API.
- **AUTHENTIK_BOOTSTRAP_EMAIL**: Set the email address for the default `akadmin` user.

**Kubernetes/Helm Configuration:**

In the Helm values, set the akadmin user password and token:

```yaml
authentik:
  bootstrap_token: "your-bootstrap-token"
  bootstrap_password: "your-bootstrap-password"
  bootstrap_email: "admin@example.com"
```

**Using Secrets (Recommended for Production):**

To store the password and token in a Kubernetes Secret (recommended for production), use:

```yaml
global:
  envFrom:
    - secretRef:
        name: authentik-bootstrap-secret
```

Create the secret:

```bash
kubectl create secret generic authentik-bootstrap-secret \
  -n authentik \
  --from-literal=AUTHENTIK_BOOTSTRAP_PASSWORD='your-secure-password' \
  --from-literal=AUTHENTIK_BOOTSTRAP_TOKEN='your-secure-token' \
  --from-literal=AUTHENTIK_BOOTSTRAP_EMAIL='admin@example.com'
```

**Using External Secrets Operator (Recommended):**

For GitOps deployments, use External Secrets Operator to pull credentials from Vault:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: authentik-bootstrap-secret
  namespace: authentik
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: authentik-bootstrap-secret
    creationPolicy: Owner
  data:
    - secretKey: AUTHENTIK_BOOTSTRAP_PASSWORD
      remoteRef:
        key: authentik/bootstrap
        property: password
    - secretKey: AUTHENTIK_BOOTSTRAP_TOKEN
      remoteRef:
        key: authentik/bootstrap
        property: token
    - secretKey: AUTHENTIK_BOOTSTRAP_EMAIL
      remoteRef:
        key: authentik/bootstrap
        property: email
```

Then reference it in your Helm values:

```yaml
global:
  envFrom:
    - secretRef:
        name: authentik-bootstrap-secret
```

**Important Notes:**

- These environment variables are **only read on the first startup**
- After the initial bootstrap, changing these values will not update the admin user
- Store bootstrap credentials securely (never commit to Git)
- Use External Secrets Operator with Vault for production deployments
- The bootstrap token can be used to authenticate to the Authentik API

#### Configuring Authentik Behind Traefik (Reverse Proxy)

**Important**: Since authentik uses WebSockets to communicate with Outposts, it does not support HTTP/1.0 reverse-proxies. The HTTP/1.0 specification does not officially support WebSockets or protocol upgrades, though some clients may allow it.

**Required Headers:**

When configuring Authentik behind Traefik, the following headers must be passed upstream:

- **X-Forwarded-Proto**: Tells authentik and Proxy Providers if they are being served over an HTTPS connection
- **X-Forwarded-For**: Without this, authentik will not know the IP addresses of clients
- **Host**: Required for various security checks, WebSocket handshake, and Outpost and Proxy Provider communication
- **Connection: Upgrade** and **Upgrade: WebSocket**: Required to upgrade protocols for requests to the WebSocket endpoints under HTTP/1.1

**TLS Configuration:**

It is also recommended to use a modern TLS configuration and disable SSL/TLS protocols older than TLS 1.3.

**Trusted Proxy CIDRs:**

If your reverse proxy isn't accessing authentik from a private IP address, trusted proxy CIDRs configuration needs to be set on the authentik server to allow client IP address detection. Configure this in your Authentik values:

```yaml
authentik:
  listen:
    trustedProxyCidrs: "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,fe80::/10,::1/128"
```

**Traefik IngressRoute Configuration:**

Create an IngressRoute for Authentik in Traefik:

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: authentik
  namespace: authentik
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`authentik.domain.tld`)
      kind: Rule
      services:
        - name: authentik-server
          port: 9443
          scheme: https
      middlewares:
        - name: authentik-headers
  tls:
    secretName: authentik-tls
---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: authentik-headers
  namespace: authentik
spec:
  headers:
    customRequestHeaders:
      X-Forwarded-Proto: https
      X-Forwarded-For: ""
      Host: authentik.domain.tld
    customResponseHeaders:
      Strict-Transport-Security: "max-age=63072000"
```

**Alternative: Using Traefik IngressRoute with Annotations:**

If using standard Kubernetes Ingress with Traefik, configure the ingress with proper annotations:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: authentik
  namespace: authentik
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.middlewares: authentik-headers@kubernetescrd
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - authentik.domain.tld
      secretName: authentik-tls
  rules:
    - host: authentik.domain.tld
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: authentik-server
                port:
                  number: 9443
```

**Traefik Middleware for WebSocket Support:**

Create a middleware to handle WebSocket upgrades:

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: authentik-headers
  namespace: authentik
spec:
  headers:
    customRequestHeaders:
      X-Forwarded-Proto: https
      X-Forwarded-For: ""
      Host: authentik.domain.tld
    customResponseHeaders:
      Strict-Transport-Security: "max-age=63072000"
  # Enable WebSocket support
  passTLSClientCert:
    pem: true
```

**Verification:**

After configuring the reverse proxy:

1. Verify WebSocket connections work by checking the Authentik UI
2. Test Outpost connectivity
3. Check Authentik logs for any proxy-related errors:
   ```bash
   kubectl logs -n authentik -l app.kubernetes.io/name=authentik | grep -i proxy
   ```

**Note**: If Authentik is accessed from a subpath (e.g., `https://domain.tld/authentik/`), configure the `AUTHENTIK_WEB__PATH` environment variable in your Authentik deployment. See the [Authentik path configuration documentation](https://goauthentik.io/docs/install-config/configuration/#authentik_web__path) for details.

#### Integrating Authentik with Harbor

**Support Level**: Community

**What is Harbor:**

Harbor is an open source container image registry that secures images with role-based access control, scans images for vulnerabilities, and signs images as trusted. A CNCF Graduated project, Harbor delivers compliance, performance, and interoperability to help you consistently and securely manage images across cloud native compute platforms like Kubernetes and Docker.

**Preparation:**

The following placeholders are used in this guide:
- `harbor.company` is the FQDN of the Harbor installation
- `authentik.company` is the FQDN of the authentik installation

**Note**: This documentation lists only the settings that you need to change from their default values. Be aware that any changes other than those explicitly mentioned in this guide could cause issues accessing your application.

**Authentik Configuration:**

To support the integration of Harbor with authentik, you need to create an application/provider pair in authentik.

**Create an Application and Provider in Authentik:**

1. Log in to authentik as an administrator and open the authentik Admin interface
2. Navigate to **Applications > Applications** and click **Create with Provider** to create an application and provider pair
   - (Alternatively you can first create a provider separately, then create the application and connect it with the provider)

3. **Application Settings:**
   - Provide a descriptive name
   - Optional group for the type of application
   - Policy engine mode
   - Optional UI settings

4. **Choose a Provider Type:**
   - Select **OAuth2/OpenID Connect** as the provider type

5. **Configure the Provider:**
   - Provide a name (or accept the auto-provided name)
   - Select the authorization flow to use for this provider
   - Configure the following required settings:

   **Protocol Settings:**
   - **Redirect URI**: `https://harbor.company/c/oidc/callback/`
   - **Strict**: Enable strict redirect URI matching
   - **Signing Key**: Select any available signing key

   **Advanced Protocol Settings:**
   - **Scopes**: Add `authentik default OAuth Mapping: OpenID 'offline_access'` to Selected Scopes

6. **Configure Bindings (Optional):**
   - You can create a binding (policy, group, or user) to manage the listing and access to applications on a user's My applications page

7. Click **Submit** to save the new application and provider

8. **Note the Client ID and Client Secret:**
   - These will be needed for Harbor configuration
   - Store these securely (preferably in Vault via External Secrets)

**Harbor Configuration:**

To support the integration of authentik with Harbor, you need to configure OIDC authentication.

1. Log in to the Harbor dashboard as an admin

2. Navigate to **Configuration** and select the **Authentication** tab

3. In the **Auth Mode** dropdown, select **OIDC** and provide the following required configurations:

   - **OIDC Provider Name**: `authentik`
   - **OIDC Endpoint**: `https://authentik.company/application/o/harbor`
     - Replace `harbor` with the slug of the application created in Authentik
   - **OIDC Client ID**: Client ID from authentik (from the provider created above)
   - **OIDC Client Secret**: Client secret from authentik (from the provider created above)
   - **OIDC Scope**: `openid,profile,email,offline_access`
   - **Username Claim**: `preferred_username`

4. Click **Save**

**Important**: If you are experiencing redirect errors, ensure that you have set the `hostname` and `external_url` fields in your `harbor.yml` file and run the setup script.

**Configuration Verification:**

To confirm that authentik is properly configured with Harbor:

1. Log out of Harbor
2. Locate the **"LOGIN VIA OIDC PROVIDER"** button on the login page
3. Click on it
4. Ensure you can successfully log in using Single Sign-On

**GitOps Configuration:**

For GitOps deployments, store the Harbor OIDC configuration in your Harbor Helm values:

```yaml
externalURL: https://harbor.company

oidc:
  name: authentik
  endpoint: https://authentik.company/application/o/harbor
  clientID: "env://HARBOR_OIDC_CLIENT_ID"  # From External Secrets
  clientSecret: "env://HARBOR_OIDC_CLIENT_SECRET"  # From External Secrets
  scope: "openid,profile,email,offline_access"
  usernameClaim: "preferred_username"
```

Use External Secrets Operator to inject the client ID and secret from Vault.

#### PostgreSQL Production Setup

The PostgreSQL installation provided by the Authentik Helm chart is intended for demonstration and testing purposes only. For production, use the shared PostgreSQL database deployed via Zalando Postgres Operator in Phase 1.5.

**PostgreSQL Cluster Details:**
- Cluster name: `platform-postgres`
- Namespace: `platform`
- Master service: `platform-postgres.platform.svc.cluster.local`
- Replica service: `platform-postgres-repl.platform.svc.cluster.local`
- Database: `authentik` (created automatically)
- Credentials Secret: `postgres.platform-postgres.credentials.postgresql.acid.zalan.do`

Configure the Authentik Helm chart to use the shared PostgreSQL instance:

```yaml
postgresql:
  enabled: false

authentik:
  postgresql:
    host: "platform-postgres.platform.svc.cluster.local"  # Zalando Postgres Operator service
    port: 5432
    database: "authentik"  # Database created by operator
    user: "zalando"  # User created by operator
    password: "env://AUTHENTIK_POSTGRESQL_PASSWORD"  # Load from External Secrets (stored in Vault)
```

**Retrieving Credentials:**

The Zalando Postgres Operator creates Kubernetes Secrets with the following naming pattern:
- `{user}.{cluster-name}.credentials.postgresql.acid.zalan.do`

To retrieve the password for the `zalando` user:
```bash
kubectl get secret postgres.platform-postgres.credentials.postgresql.acid.zalan.do \
  -n platform \
  -o jsonpath='{.data.password}' | base64 -d
```

Store this password in Vault and configure External Secrets Operator to inject it as `AUTHENTIK_POSTGRESQL_PASSWORD`.

#### Authentik PostgreSQL Configuration

Authentik requires PostgreSQL database configuration via environment variables. All settings use double-underscores (`__`) to indicate nested YAML structure.

**Connection Settings:**

```yaml
authentik:
  postgresql:
    host: "postgresql.platform.svc.cluster.local"
    port: 5432
    user: "authentik"
    password: "env://AUTHENTIK_POSTGRESQL_PASSWORD"  # From External Secrets
    name: "authentik"
```

**Environment Variables (for Kubernetes):**

- `AUTHENTIK_POSTGRESQL__HOST`: Hostname or IP address of PostgreSQL server
- `AUTHENTIK_POSTGRESQL__PORT`: Port (default: 5432)
- `AUTHENTIK_POSTGRESQL__USER`: Username for PostgreSQL
- `AUTHENTIK_POSTGRESQL__PASSWORD`: Password (can use `env://<name>` format)
- `AUTHENTIK_POSTGRESQL__NAME`: Database name

**SSL/TLS Settings:**

- `AUTHENTIK_POSTGRESQL__SSLMODE`: SSL verification mode
  - `disable`: No SSL
  - `allow`: Use SSL if available, no verification
  - `prefer`: Attempt SSL first, fallback to non-SSL
  - `require`: Require SSL, no certificate verification
  - `verify-ca`: Require SSL, verify CA (default)
  - `verify-full`: Require SSL, verify CA and hostname
- `AUTHENTIK_POSTGRESQL__SSLROOTCERT`: Path to CA certificate file
- `AUTHENTIK_POSTGRESQL__SSLCERT`: Path to client SSL certificate
- `AUTHENTIK_POSTGRESQL__SSLKEY`: Path to client private key

**Connection Management (Important for Connection Poolers):**

- `AUTHENTIK_POSTGRESQL__CONN_MAX_AGE`: Maximum age of database connection in seconds
  - `0` (default): Connections closed after each request
  - `> 0`: Enables persistent connections
  - `None`: Unlimited persistence (use with caution with poolers)
- `AUTHENTIK_POSTGRESQL__CONN_HEALTH_CHECKS`: Enable health checks on persistent connections (default: false)
- `AUTHENTIK_POSTGRESQL__DISABLE_SERVER_SIDE_CURSORS`: Disable server-side cursors (default: false)
  - **Must be `true` when using transaction-based connection poolers**

**Advanced Settings:**

- `AUTHENTIK_POSTGRESQL__DEFAULT_SCHEMA`: Database schema name (default: `public`)
  - Can only be set before first startup
- `AUTHENTIK_POSTGRESQL__CONN_OPTIONS`: Base64-encoded JSON dictionary of libpq parameters

**Read Replicas:**

Configure read replicas for load distribution:

```yaml
# First read replica (index 0)
AUTHENTIK_POSTGRESQL__READ_REPLICAS__0__HOST
AUTHENTIK_POSTGRESQL__READ_REPLICAS__0__NAME
AUTHENTIK_POSTGRESQL__READ_REPLICAS__0__USER
AUTHENTIK_POSTGRESQL__READ_REPLICAS__0__PORT
AUTHENTIK_POSTGRESQL__READ_REPLICAS__0__PASSWORD
# ... same SSL and connection settings as primary
```

**Using PostgreSQL Connection Pooler (PgBouncer/PgPool):**

When using a connection pooler:

1. **For Session Pool Mode:**
   - Set `AUTHENTIK_POSTGRESQL__CONN_MAX_AGE` to a value lower than any timeout (or 0 to disable)

2. **For Transaction Pool Mode:**
   - Set `AUTHENTIK_POSTGRESQL__DISABLE_SERVER_SIDE_CURSORS: true` (required)
   - Configure `AUTHENTIK_POSTGRESQL__CONN_MAX_AGE` appropriately

**Hot-Reloading:**

The following settings support hot-reloading (can be changed without restart):
- `AUTHENTIK_POSTGRESQL__HOST`
- `AUTHENTIK_POSTGRESQL__PORT`
- `AUTHENTIK_POSTGRESQL__USER`
- `AUTHENTIK_POSTGRESQL__PASSWORD`

Adding or removing read replicas requires a restart.

#### Email Configuration (Recommended)

Configure global email settings for:
- Administrator alerts
- Configuration issue notifications
- New release notifications
- Email stages (verification/recovery emails)

Example configuration:

```yaml
authentik:
  email:
    host: "smtp.example.com"
    port: 587
    username: "authentik@example.com"
    password: "email-password"
    use_tls: true
    from: "authentik@example.com"
```

For more information, refer to the [Authentik Email configuration documentation](https://goauthentik.io/docs/configuration/email).

#### Integration with Argo CD Application

The Authentik Argo CD Application manifest should reference a values file stored in Git:

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
    targetRevision: 2024.10.0
    helm:
      valueFiles:
        - $values/authentik/helm-values/authentik-values.yaml
    - repoURL: https://github.com/alanredfordhayes/platform.git
      targetRevision: HEAD
      ref: values
```

This allows sensitive values to be managed via External Secrets Operator pulling from Vault.

### Argo CD User Management and SSO Configuration

#### Overview

Once installed, Argo CD has one built-in admin user that has full access to the system. It is recommended to use the admin user only for initial configuration and then switch to local users or configure SSO integration.

#### Local Users/Accounts

The local users/accounts feature serves two main use-cases:

1. **Auth tokens for Argo CD management automation**: It is possible to configure an API account with limited permissions and generate an authentication token. Such token can be used to automatically create applications, projects, etc.

2. **Additional users for small teams**: For very small teams where use of SSO integration might be considered overkill. The local users don't provide advanced features such as groups, login history, etc. So if you need such features it is strongly recommended to use SSO.

**Note**: When you create local users, each of those users will need additional RBAC rules set up, otherwise they will fall back to the default policy specified by `policy.default` field of the `argocd-rbac-cm` ConfigMap.

The maximum length of a local account's username is 32.

#### Create New User

New users should be defined in `argocd-cm` ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  # add an additional local user with apiKey and login capabilities
  #   apiKey - allows generating API keys
  #   login - allows to login using UI
  accounts.alice: apiKey, login
  # disables user. User is enabled by default
  accounts.alice.enabled: "false"
```

Each user might have two capabilities:
- **apiKey**: allows generating authentication tokens for API access
- **login**: allows to login using UI

#### Delete User

In order to delete a user, you must remove the corresponding entry defined in the `argocd-cm` ConfigMap:

```bash
kubectl patch -n argocd cm argocd-cm --type='json' -p='[{"op": "remove", "path": "/data/accounts.alice"}]'
```

It is recommended to also remove the password entry in the `argocd-secret` Secret:

```bash
kubectl patch -n argocd secrets argocd-secret --type='json' -p='[{"op": "remove", "path": "/data/accounts.alice.password"}]'
```

#### Disable Admin User

As soon as additional users are created, it is recommended to disable the admin user:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  admin.enabled: "false"
```

#### Manage Users

The Argo CD CLI provides a set of commands to set user password and generate tokens.

**Get full users list:**
```bash
argocd account list
```

**Get specific user details:**
```bash
argocd account get --account <username>
```

**Set user password:**
```bash
# if you are managing users as the admin user, <current-user-password> should be the current admin password.
argocd account update-password \
  --account <name> \
  --current-password <current-user-password> \
  --new-password <new-user-password>
```

**Generate auth token:**
```bash
# if flag --account is omitted then Argo CD generates token for current user
argocd account generate-token --account <username>
```

#### Failed Logins Rate Limiting

Argo CD rejects login attempts after too many failed attempts in order to prevent password brute-forcing. The following environment variables are available to control throttling settings:

- **ARGOCD_SESSION_FAILURE_MAX_FAIL_COUNT**: Maximum number of failed logins before Argo CD starts rejecting login attempts. Default: 5.
- **ARGOCD_SESSION_FAILURE_WINDOW_SECONDS**: Number of seconds for the failure window. Default: 300 (5 minutes). If this is set to 0, the failure window is disabled and the login attempts gets rejected after 10 consecutive logon failures, regardless of the time frame they happened.
- **ARGOCD_SESSION_MAX_CACHE_SIZE**: Maximum number of entries allowed in the cache. Default: 1000
- **ARGOCD_MAX_CONCURRENT_LOGIN_REQUESTS_COUNT**: Limits max number of concurrent login requests. If set to 0 then limit is disabled. Default: 50.

#### SSO Configuration

There are two ways that SSO can be configured:

1. **Bundled Dex OIDC provider** - Use this option if your current provider does not support OIDC (e.g. SAML, LDAP) or if you wish to leverage any of Dex's connector features (e.g. the ability to map GitHub organizations and teams to OIDC groups claims). Dex also supports OIDC directly and can fetch user information from the identity provider when the groups cannot be included in the IDToken.

2. **Existing OIDC provider** - Use this if you already have an OIDC provider which you are using (e.g. Okta, OneLogin, Auth0, Microsoft, Keycloak, Google (G Suite), Authentik), where you manage your users, groups, and memberships.

#### Dex Configuration

Argo CD embeds and bundles Dex as part of its installation, for the purpose of delegating authentication to an external identity provider. Multiple types of identity providers are supported (OIDC, SAML, LDAP, GitHub, etc.). SSO configuration of Argo CD requires editing the `argocd-cm` ConfigMap with Dex connector settings.

**1. Register the Application in the Identity Provider:**

In your identity provider (e.g., Authentik), register a new application. The callback address should be the `/api/dex/callback` endpoint of your Argo CD URL (e.g. `https://argocd.example.com/api/dex/callback`).

After registering the app, you will receive an OAuth2 client ID and secret. These values will be inputted into the Argo CD configmap.

**2. Configure Argo CD for SSO:**

Edit the `argocd-cm` configmap:

```bash
kubectl edit configmap argocd-cm -n argocd
```

In the `url` key, input the base URL of Argo CD. In this example, it is `https://argocd.example.com`

(Optional): If Argo CD should be accessible via multiple base URLs you may specify any additional base URLs via the `additionalUrls` key.

In the `dex.config` key, add the connector to the `connectors` sub field. For Authentik, use the OIDC connector:

```yaml
data:
  url: https://argocd.example.com
  dex.config: |
    connectors:
      # OIDC with Authentik
      - type: oidc
        id: authentik
        name: Authentik
        config:
          issuer: https://authentik.company
          clientID: aabbccddeeff00112233
          clientSecret: $dex.authentik.clientSecret
          insecureEnableGroups: true
          scopes:
          - profile
          - email
          - groups
          getUserInfo: true
```

**OIDC Configuration with Dex:**

Dex can be used for OIDC authentication. This provides a separate set of features such as fetching information from the UserInfo endpoint and federated tokens.

**Requesting Additional ID Token Claims:**

By default Dex only retrieves the profile and email scopes. In order to retrieve more claims you can add them under the `scopes` entry in the Dex configuration. To enable group claims through Dex, `insecureEnableGroups` also needs to be enabled. Group information is currently only refreshed at authentication time.

**Retrieving Claims that are Not in the Token:**

When an IdP does not or cannot support certain claims in an IDToken they can be retrieved separately using the UserInfo endpoint. Dex supports this functionality using the `getUserInfo` endpoint. One of the most common claims that is not supported in the IDToken is the groups claim and both `getUserInfo` and `insecureEnableGroups` must be set to true.

**Warning**: Because group information is only refreshed at authentication time, just adding or removing an account from a group will not change a user's membership until they reauthenticate. Depending on your organization's needs this could be a security risk and could be mitigated by changing the authentication token's lifetime.

#### Existing OIDC Provider (Authentik)

To configure Argo CD to delegate authentication to Authentik as an existing OIDC provider, add the OAuth2 configuration to the `argocd-cm` ConfigMap under the `oidc.config` key:

```yaml
data:
  url: https://argocd.example.com
  oidc.config: |
    name: Authentik
    issuer: https://authentik.company
    clientID: aabbccddeeff00112233
    clientSecret: $oidc.authentik.clientSecret
    # Optional list of allowed aud claims
    allowedAudiences:
    - aabbccddeeff00112233
    # Optional. If false, tokens without an audience will always fail validation
    skipAudienceCheckWhenTokenHasNoAudience: true
    # Optional set of OIDC scopes to request
    requestedScopes: ["openid", "profile", "email", "groups"]
    # Optional set of OIDC claims to request on the ID token
    requestedIDTokenClaims: {"groups": {"essential": true}}
    # Optional: PKCE for authorization code interception attack prevention
    enablePKCEAuthentication: true
```

**Note**: The callback address should be the `/auth/callback` endpoint of your Argo CD URL (e.g. `https://argocd.example.com/auth/callback`).

**Requesting Additional ID Token Claims:**

Individual claims can be requested with `requestedIDTokenClaims`:

```yaml
oidc.config: |
  requestedIDTokenClaims:
    email:
      essential: true
    groups:
      essential: true
      value: org:myorg
```

For a simple case:
```yaml
oidc.config: |
  requestedIDTokenClaims: {"groups": {"essential": true}}
```

**Retrieving Group Claims When Not in the Token:**

Some OIDC providers don't return the group information for a user in the ID token. They instead provide the groups on the user info endpoint. With the following config, Argo CD queries the user info endpoint during login for groups information:

```yaml
oidc.config: |
  enableUserInfoGroups: true
  userInfoPath: /userinfo
  userInfoCacheExpiration: "5m"
```

**Note**: If you omit the `userInfoCacheExpiration` setting or if it's greater than the expiration of the ID token, the argocd-server will cache group information as long as the ID token is valid!

**Configuring a Custom Logout URL:**

Optionally, if your OIDC provider exposes a logout API, you can configure a custom logout URL:

```yaml
oidc.config: |
  name: Authentik
  issuer: https://authentik.company
  clientID: xxxxxxxxx
  clientSecret: xxxxxxxxx
  requestedScopes: ["openid", "profile", "email", "groups"]
  requestedIDTokenClaims: {"groups": {"essential": true}}
  logoutURL: https://authentik.company/logout?id_token_hint={{token}}&post_logout_redirect_uri={{logoutRedirectURL}}
```

**Configuring a Custom Root CA Certificate:**

If your OIDC provider is setup with a certificate which is not signed by one of the well known certificate authorities, you can provide a custom certificate:

```yaml
oidc.config: |
  ...
  rootCA: |
    -----BEGIN CERTIFICATE-----
    ... encoded certificate data here ...
    -----END CERTIFICATE-----
```

**Skipping Certificate Verification:**

By default, all connections made by the API server to OIDC providers must pass certificate validation. If you need to disable this (not recommended for production), set `oidc.tls.insecure.skip.verify` to `"true"` in the `argocd-cm` ConfigMap.

#### Sensitive Data and SSO Client Secrets

The `argocd-secret` can be used to store sensitive data which can be referenced by ArgoCD. Values starting with `$` in configmaps are interpreted as follows:

- If value has the form: `$<secret>:a.key.in.k8s.secret`, look for a k8s secret with the name `<secret>` (minus the `$`), and read its value.
- Otherwise, look for a key in the k8s secret named `argocd-secret`.

**Example - Using argocd-secret:**

```yaml
# argocd-secret
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-secret
    app.kubernetes.io/part-of: argocd
type: Opaque
data:
  # The secret value must be base64 encoded **once**
  # this value corresponds to: `printf "hello-world" | base64`
  oidc.authentik.clientSecret: "aGVsbG8td29ybGQ="

# argocd-cm
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  oidc.config: |
    name: Authentik
    clientID: aabbccddeeff00112233
    # Reference key in argocd-secret
    clientSecret: $oidc.authentik.clientSecret
```

**Alternative - Using External Secrets:**

If you want to store sensitive data in another Kubernetes Secret (recommended for GitOps), use External Secrets Operator:

```yaml
# ExternalSecret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: argocd-oidc-secret
  namespace: argocd
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: argocd-oidc-secret
    creationPolicy: Owner
  data:
    - secretKey: oidc.authentik.clientSecret
      remoteRef:
        key: argocd/oidc
        property: clientSecret

# argocd-cm
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  oidc.config: |
    name: Authentik
    clientID: aabbccddeeff00112233
    # Reference key in external secret (must have label app.kubernetes.io/part-of: argocd)
    clientSecret: $argocd-oidc-secret:oidc.authentik.clientSecret
```

**Note**: The secret must have the label `app.kubernetes.io/part-of: argocd` for Argo CD to access it.

### Argo CD RBAC Configuration

#### Overview

The RBAC feature enables restrictions of access to Argo CD resources. Argo CD does not have its own user management system and has only one built-in user, `admin`. The admin user is a superuser and it has unrestricted access to the system. RBAC requires SSO configuration or one or more local users setup. Once SSO or local users are configured, additional RBAC roles can be defined, and SSO groups or local users can then be mapped to roles.

There are two main components where RBAC configuration can be defined:

1. The global RBAC config map (`argocd-rbac-cm`)
2. The AppProject's roles

#### Basic Built-in Roles

Argo CD has two pre-defined roles but RBAC configuration allows defining roles and groups:

- **role:readonly**: read-only access to all resources
- **role:admin**: unrestricted access to all resources

These default built-in role definitions can be seen in `builtin-policy.csv`.

#### Default Policy for Authenticated Users

When a user is authenticated in Argo CD, it will be granted the role specified in `policy.default`.

**Restricting Default Permissions:**

All authenticated users get at least the permissions granted by the default policies. This access cannot be blocked by a deny rule. It is recommended to create a new `role:authenticated` with the minimum set of permissions possible, then grant permissions to individual roles as needed.

#### Anonymous Access

Enabling anonymous access to the Argo CD instance allows users to assume the default role permissions specified by `policy.default` without being authenticated.

The anonymous access to Argo CD can be enabled using the `users.anonymous.enabled` field in `argocd-cm`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  users.anonymous.enabled: "true"
```

**Warning**: When enabling anonymous access, consider creating a new default role and assigning it to the default policies with `policy.default: role:unauthenticated`.

#### RBAC Model Structure

The model syntax is based on Casbin (an open source ACL/ACLs). There are two different types of syntax: one for assigning policies, and another one for assigning users to internal roles.

**Group**: Allows to assign authenticated users/groups to internal roles.

Syntax: `g, <user/group>, <role>`

- **<user/group>**: The entity to whom the role will be assigned. It can be a local user or a user authenticated with SSO. When SSO is used, the user will be based on the `sub` claims, while the group is one of the values returned by the scopes configuration.
- **<role>**: The internal role to which the entity will be assigned.

**Policy**: Allows to assign permissions to an entity.

Syntax: `p, <role/user/group>, <resource>, <action>, <object>, <effect>`

- **<role/user/group>**: The entity to whom the policy will be assigned
- **<resource>**: The type of resource on which the action is performed
- **<action>**: The operation that is being performed on the resource
- **<object>**: The object identifier representing the resource on which the action is performed. Depending on the resource, the object's format will vary.
- **<effect>**: Whether this policy should grant or restrict the operation on the target object. One of `allow` or `deny`.

**Resource and Action Matrix:**

| Resource\Action | get | create | update | delete | sync | action | override | invoke |
|----------------|-----|--------|--------|--------|------|--------|----------|--------|
| applications | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| applicationsets | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| clusters | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| projects | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| repositories | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| accounts | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| certificates | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| gpgkeys | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| logs | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| exec | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| extensions | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

#### Application-Specific Policy

Some policies only have meaning within an application. It is the case with the following resources:

- applications
- applicationsets
- logs
- exec

While they can be set in the global configuration, they can also be configured in AppProject's roles. The expected `<object>` value in the policy structure is replaced by `<app-project>/<app-name>`.

For instance, these policies would grant `example-user` access to get any applications, but only be able to see logs in `my-app` application part of the `example-project` project:

```
p, example-user, applications, get, *, allow
p, example-user, logs, get, example-project/my-app, allow
```

**Application in Any Namespaces:**

When application in any namespace is enabled, the expected `<object>` value in the policy structure is replaced by `<app-project>/<app-ns>/<app-name>`. Since multiple applications could have the same name in the same project, the policy below makes sure to restrict access only to `app-namespace`:

```
p, example-user, applications, get, */app-namespace/*, allow
p, example-user, logs, get, example-project/app-namespace/my-app, allow
```

#### Fine-grained Permissions for update/delete action

The `update` and `delete` actions, when granted on an application, will allow the user to perform the operation on the application itself, but not on its resources.

To do so, when the action is performed on an application's resource, the `<action>` will have the `<action>/<group>/<kind>/<ns>/<name>` format.

For instance, to grant access to `example-user` to only delete Pods in the `prod-app` Application, the policy could be:

```
p, example-user, applications, delete/*/Pod/*/*, default/prod-app, allow
```

**Understand glob pattern behavior:**

Argo CD RBAC does not use `/` as a separator when evaluating glob patterns. So the pattern `delete/*/kind/*` will match `delete/<group>/kind/<namespace>/<name>` but also `delete/<group>/<kind>/kind/<name>`. It is better to always include all the parts of the resource in the pattern (always use four slashes).

**Examples:**

If we want to grant access to the user to update all resources of an application, but not the application itself:

```
p, example-user, applications, update/*, default/prod-app, allow
```

If we want to explicitly deny delete of the application, but allow the user to delete Pods:

```
p, example-user, applications, delete, default/prod-app, deny
p, example-user, applications, delete/*/Pod/*/*, default/prod-app, allow
```

If we want to explicitly allow updates to the application, but deny updates to any sub-resources:

```
p, example-user, applications, update, default/prod-app, allow
p, example-user, applications, update/*, default/prod-app, deny
```

**Preserve Application permission Inheritance (Since v3.0.0):**

Prior to v3, update and delete actions (without a `/*`) were also evaluated on sub-resources. To preserve this behavior, you can set the config value `server.rbac.disableApplicationFineGrainedRBACInheritance` to `false` in the Argo CD ConfigMap `argocd-cm`.

#### The action action

The `action` action corresponds to either built-in resource customizations defined in the Argo CD repository, or to custom resource actions defined by you.

The `<action>` has the `action/<group>/<kind>/<action-name>` format.

For example, a resource customization path `resource_customizations/extensions/DaemonSet/actions/restart/action.lua` corresponds to the action path `action/extensions/DaemonSet/restart`. If the resource is not under a group (for example, Pods or ConfigMaps), then the path will be `action//Pod/action-name`.

**Examples:**

The following policies allows the user to perform any action on the DaemonSet resources, as well as the `maintenance-off` action on a Pod:

```
p, example-user, applications, action//Pod/maintenance-off, default/*, allow
p, example-user, applications, action/extensions/DaemonSet/*, default/*, allow
```

To allow the user to perform any actions:

```
p, example-user, applications, action/*, default/*, allow
```

#### The override action

When granted along with the `sync` action, the `override` action will allow a user to synchronize local manifests to the Application. These manifests will be used instead of the configured source, until the next sync is performed.

#### The applicationsets resource

The `applicationsets` resource is an Application-Specific policy.

ApplicationSets provide a declarative way to automatically create/update/delete Applications. Allowing the `create` action on the resource effectively grants the ability to create Applications. While it doesn't allow the user to create Applications directly, they can create Applications via an ApplicationSet.

With the resource being application-specific, the `<object>` of the applicationsets policy will have the format `<app-project>/<app-name>`. However, since an ApplicationSet does belong to any project, the `<app-project>` value represents the projects in which the ApplicationSet will be able to create Applications.

With the following policy, a `dev-group` user will be unable to create an ApplicationSet capable of creating Applications outside the `dev-project` project:

```
p, dev-group, applicationsets, *, dev-project/*, allow
```

#### The logs resource

The `logs` resource is an Application-Specific Policy.

When granted with the `get` action, this policy allows a user to see Pod's logs of an application via the Argo CD UI. The functionality is similar to `kubectl logs`.

#### The exec resource

The `exec` resource is an Application-Specific Policy.

When granted with the `create` action, this policy allows a user to exec into Pods of an application via the Argo CD UI. The functionality is similar to `kubectl exec`.

#### The extensions resource

With the `extensions` resource, it is possible to configure permissions to invoke proxy extensions. The extensions RBAC validation works in conjunction with the applications resource. A user needs to have read permission on the application where the request is originated from.

Consider the example below, it will allow the `example-user` to invoke the `httpbin` extensions in all applications under the `default` project:

```
p, example-user, applications, get, default/*, allow
p, example-user, extensions, invoke, httpbin, allow
```

#### The deny effect

When `deny` is used as an effect in a policy, it will be effective if the policy matches. Even if more specific policies with the `allow` effect match as well, the `deny` will have priority.

The order in which the policies appears in the policy file configuration has no impact, and the result is deterministic.

#### Policies Evaluation and Matching

The evaluation of access is done in two parts: validating against the default policy configuration, then validating against the policies for the current user.

If an action is allowed or denied by the default policies, then this effect will be effective without further evaluation. When the effect is undefined, the evaluation will continue with subject-specific policies.

The access will be evaluated for the user, then for each configured group that the user is part of.

The matching engine, configured in `policy.matchMode`, can use two different match modes to compare the values of tokens:

- **glob**: based on the glob package
- **regex**: based on the regexp package

When all tokens match during the evaluation, the effect will be returned. The evaluation will continue until all matching policies are evaluated, or until a policy with the `deny` effect matches. After all policies are evaluated, if there was at least one `allow` effect and no `deny`, access will be granted.

**Glob matching:**

When glob is used, the policy tokens are treated as single terms, without separators.

Consider the following policy:

```
p, example-user, applications, action/extensions/*, default/*, allow
```

When the `example-user` executes the `extensions/DaemonSet/test` action, the following glob matches will happen:

- The current user `example-user` matches the token `example-user`
- The value `applications` matches the token `applications`
- The value `action/extensions/DaemonSet/test` matches `action/extensions/*`. Note that `/` is not treated as a separator and the use of `**` is not necessary
- The value `default/my-app` matches `default/*`

#### Using SSO Users/Groups

The `scopes` field controls which OIDC scopes to examine during RBAC enforcement (in addition to `sub` scope). If omitted, it defaults to `'[groups]'`. The scope value can be a string, or a list of strings.

The following example shows targeting email as well as groups from your OIDC provider:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-rbac-cm
    app.kubernetes.io/part-of: argocd
data:
  policy.csv: |
    p, my-org:team-alpha, applications, sync, my-project/*, allow
    g, my-org:team-beta, role:admin
    g, user@example.org, role:admin
  policy.default: role:readonly
  scopes: '[groups, email]'
```

This can be useful to associate users' emails and groups directly in AppProject:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-beta-project
  namespace: argocd
spec:
  roles:
    - name: admin
      description: Admin privileges to team-beta
      policies:
        - p, proj:team-beta-project:admin, applications, *, *, allow
      groups:
        - user@example.org # Value from the email scope
        - my-org:team-beta # Value from the groups scope
```

#### Local Users/Accounts

Local users are assigned access by either grouping them with a role or by assigning policies directly to them.

**Assign policy directly to a local user:**

```
p, my-local-user, applications, sync, my-project/*, allow
```

**Assign a role to a local user:**

```
g, my-local-user, role:admin
```

**Ambiguous Group Assignments:**

If you have enabled SSO, any SSO user with a scope that matches a local user will be added to the same roles as the local user. For example, if local user `sally` is assigned to `role:admin`, and if an SSO user has a scope which happens to be named `sally`, that SSO user will also be assigned to `role:admin`.

To avoid ambiguity, if you are using local users and SSO, it is recommended to assign policies directly to local users, and not to assign roles to local users. In other words, instead of using `g, my-local-user, role:admin`, you should explicitly assign policies to `my-local-user`:

```
p, my-local-user, *, *, *, allow
```

#### Policy CSV Composition

It is possible to provide additional entries in the `argocd-rbac-cm` configmap to compose the final policy csv. In this case, the key must follow the pattern `policy.<any string>.csv`. Argo CD will concatenate all additional policies it finds with this pattern below the main one (`policy.csv`). The order of additional provided policies are determined by the key string.

Example: if two additional policies are provided with keys `policy.A.csv` and `policy.B.csv`, it will first concatenate `policy.A.csv` and then `policy.B.csv`.

This is useful to allow composing policies in config management tools like Kustomize, Helm, etc.

The example below shows how a Kustomize patch can be provided in an overlay to add additional configuration to an existing RBAC ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.tester-overlay.csv: |
    p, role:tester, applications, *, */*, allow
    p, role:tester, projects, *, *, allow
    g, my-org:team-qa, role:tester
```

#### Validating and Testing Your RBAC Policies

If you want to ensure that your RBAC policies are working as expected, you can use the `argocd admin settings rbac` command to validate them. This tool allows you to test whether a certain role or subject can perform the requested action with a policy that's not live yet in the system, i.e. from a local file or config map. Additionally, it can be used against the live RBAC configuration in the cluster your Argo CD is running in.

**Validating a policy:**

To check whether your new policy configuration is valid and understood by Argo CD's RBAC implementation, you can use:

```bash
argocd admin settings rbac validate
```

**Testing a policy:**

To test whether a role or subject (group or local user) has sufficient permissions to execute certain actions on certain resources, you can use:

```bash
argocd admin settings rbac can <subject> <action> <resource> <object>
```

Example:
```bash
argocd admin settings rbac can my-org:team-alpha sync applications my-project/my-app
```

### Argo CD Ingress Configuration with Traefik (v3.0)

Traefik can be used as an edge router and provide TLS termination within the same deployment. It currently has an advantage over NGINX in that it can terminate both TCP and HTTP connections on the same port, meaning you do not require multiple hosts or paths.

#### Prerequisites

The Argo CD API server should be run with TLS disabled. Edit the `argocd-server` deployment to add the `--insecure` flag to the `argocd-server` command or set `server.insecure: "true"` in the `argocd-cmd-params-cm` ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  server.insecure: "true"
```

#### Traefik IngressRoute Configuration

Create an IngressRoute for Argo CD server using Traefik's IngressRoute CRD:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: argocd-server
  namespace: argocd
spec:
  entryPoints:
    - websecure
  routes:
    - kind: Rule
      match: Host(`argocd.example.com`)
      priority: 10
      services:
        - name: argocd-server
          port: 80
    - kind: Rule
      match: Host(`argocd.example.com`) && Header(`Content-Type`, `application/grpc`)
      priority: 11
      services:
        - name: argocd-server
          port: 80
          scheme: h2c
  tls:
    certResolver: default
```

**Configuration Notes:**

- **Entry Points**: `websecure` is the HTTPS entry point (typically port 443)
- **Routes**: Two routes are defined:
  - Standard HTTP route for web UI and API access
  - gRPC route for streaming operations (using `h2c` scheme for HTTP/2 cleartext)
- **TLS**: Uses Traefik's certificate resolver (`default`) for automatic TLS certificate management
- **Priority**: The gRPC route has higher priority (11) to match before the standard HTTP route (10)

**File Location:**

This IngressRoute should be created in:
- `argocd/app-of-apps/apps/network/argocd-ingressroute.yaml`

**Integration with Argo CD Application:**

The IngressRoute can be managed by Argo CD as part of the network parent application:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd-ingressroute
  namespace: argocd
  labels:
    app.kubernetes.io/instance: network
    app.kubernetes.io/name: argocd-ingressroute
spec:
  destination:
    namespace: argocd
    server: https://kubernetes.default.svc
  project: network
  source:
    repoURL: https://github.com/alanredfordhayes/platform.git
    targetRevision: HEAD
    path: argocd/app-of-apps/apps/network
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

### Argo CD Security

Argo CD has undergone rigorous internal security reviews and penetration testing to satisfy PCI compliance requirements. The following are security topics and implementation details of Argo CD.

#### Authentication

Authentication to Argo CD API server is performed exclusively using JSON Web Tokens (JWTs). Username/password bearer tokens are not used for authentication. The JWT is obtained/managed in one of the following ways:

**Local Admin User:**

For the local admin user, a username/password is exchanged for a JWT using the `/api/v1/session` endpoint. This token is signed & issued by the Argo CD API server itself and it expires after 24 hours (this token used not to expire, see CVE-2021-26921). When the admin password is updated, all existing admin JWT tokens are immediately revoked. The password is stored as a bcrypt hash in the `argocd-secret` Secret.

**Single Sign-On Users:**

For Single Sign-On users, the user completes an OAuth2 login flow to the configured OIDC identity provider (either delegated through the bundled Dex provider, or directly to a self-managed OIDC provider). This JWT is signed & issued by the IDP, and expiration and revocation is handled by the provider. Dex tokens expire after 24 hours.

**Automation Tokens:**

Automation tokens are generated for a project using the `/api/v1/projects/{project}/roles/{role}/token` endpoint, and are signed & issued by Argo CD. These tokens are limited in scope and privilege, and can only be used to manage application resources in the project which it belongs to. Project JWTs have a configurable expiration and can be immediately revoked by deleting the JWT reference ID from the project role.

#### Authorization

Authorization is performed by iterating the list of group membership in a user's JWT groups claims, and comparing each group against the roles/rules in the RBAC policy. Any matched rule permits access to the API request.

#### TLS

All network communication is performed over TLS including service-to-service communication between the three components (`argocd-server`, `argocd-repo-server`, `argocd-application-controller`). The Argo CD API server can enforce the use of TLS 1.2 using the flag: `--tlsminversion 1.2`. Communication with Redis is performed over plain HTTP by default. TLS can be setup with command line arguments.

#### Git & Helm Repositories

Git and helm repositories are managed by a stand-alone service, called the `repo-server`. The repo-server does not carry any Kubernetes privileges and does not store credentials to any services (including git). The repo-server is responsible for cloning repositories which have been permitted and trusted by Argo CD operators, and generating Kubernetes manifests at a given path in the repository. For performance and bandwidth efficiency, the repo-server maintains local clones of these repositories so that subsequent commits to the repository are efficiently downloaded.

There are security considerations when configuring git repositories that Argo CD is permitted to deploy from. In short, gaining unauthorized write access to a git repository trusted by Argo CD will have serious security implications outlined below.

#### Unauthorized Deployments

Since Argo CD deploys the Kubernetes resources defined in git, an attacker with access to a trusted git repo would be able to affect the Kubernetes resources which are deployed. For example, an attacker could:

- Update the deployment manifest to deploy malicious container images to the environment
- Delete resources in git causing them to be pruned in the live environment

#### Tool Command Invocation

In addition to raw YAML, Argo CD natively supports two popular Kubernetes config management tools, helm and kustomize. When rendering manifests, Argo CD executes these config management tools (i.e. `helm template`, `kustomize build`) to generate the manifests. It is possible that an attacker with write access to a trusted git repository may construct malicious helm charts or kustomizations that attempt to read files out-of-tree. This includes:

- Adjacent git repos
- Files on the repo-server itself

Whether or not this is a risk to your organization depends on if the contents in the git repos are sensitive in nature. By default, the repo-server itself does not contain sensitive information, but might be configured with Config Management Plugins which do (e.g. decryption keys). If such plugins are used, extreme care must be taken to ensure the repository contents can be trusted at all times.

**Disabling Config Management Tools:**

Optionally the built-in config management tools might be individually disabled. If you know that your users will not need a certain config management tool, it's advisable to disable that tool. See Tool Detection for more information.

#### Remote Bases and Helm Chart Dependencies

Argo CD's repository allow-list only restricts the initial repository which is cloned. However, both kustomize and helm contain features to reference and follow additional repositories (e.g. kustomize remote bases, helm chart dependencies), of which might not be in the repository allow-list. Argo CD operators must understand that users with write access to trusted git repositories could reference other remote git repositories containing Kubernetes resources not easily searchable or auditable in the configured git repositories.

#### Sensitive Information

**Secrets:**

Argo CD never returns sensitive data from its API, and redacts all sensitive data in API payloads and logs. This includes:

- Cluster credentials
- Git credentials
- OAuth2 client secrets
- Kubernetes Secret values

#### External Cluster Credentials

To manage external clusters, Argo CD stores the credentials of the external cluster as a Kubernetes Secret in the `argocd` namespace. This secret contains the K8s API bearer token associated with the `argocd-manager` ServiceAccount created during `argocd cluster add`, along with connection options to that API server (TLS configuration/certs, AWS role-arn, etc...). The information is used to reconstruct a REST config and kubeconfig to the cluster used by Argo CD services.

**Rotating Bearer Tokens:**

To rotate the bearer token used by Argo CD, the token can be deleted (e.g. using kubectl) which causes Kubernetes to generate a new secret with a new bearer token. The new token can be re-inputted to Argo CD by re-running `argocd cluster add`. Run the following commands against the managed cluster:

```bash
# run using a kubeconfig for the externally managed cluster
kubectl delete secret argocd-manager-token-XXXXXX -n kube-system
argocd cluster add CONTEXTNAME
```

**Note:** Kubernetes 1.24 stopped automatically creating tokens for Service Accounts. Starting in Argo CD 2.4, `argocd cluster add` creates a ServiceAccount and a non-expiring Service Account token Secret when adding 1.24 clusters. In the future, Argo CD will add support for the Kubernetes TokenRequest API to avoid using long-lived tokens.

**Revoking Cluster Access:**

To revoke Argo CD's access to a managed cluster, delete the RBAC artifacts against the managed cluster, and remove the cluster entry from Argo CD:

```bash
# run using a kubeconfig for the externally managed cluster
kubectl delete sa argocd-manager -n kube-system
kubectl delete clusterrole argocd-manager-role
kubectl delete clusterrolebinding argocd-manager-role-binding
argocd cluster rm https://your-kubernetes-cluster-addr
```

**Note:** For AWS EKS clusters, the `get-token` command is used to authenticate to the external cluster, which uses IAM roles in lieu of locally stored tokens, so token rotation is not needed, and revocation is handled through IAM.

#### Cluster RBAC

By default, Argo CD uses a `clusteradmin` level role in order to:

- Watch & operate on cluster state
- Deploy resources to the cluster

Although Argo CD requires cluster-wide read privileges to resources in the managed cluster to function properly, it does not necessarily need full write privileges to the cluster. The ClusterRole used by `argocd-server` and `argocd-application-controller` can be modified such that write privileges are limited to only the namespaces and resources that you wish Argo CD to manage.

**Fine-tuning External Cluster Privileges:**

To fine-tune privileges of externally managed clusters, edit the ClusterRole of the `argocd-manager-role`:

```bash
# run using a kubeconfig for the externally managed cluster
kubectl edit clusterrole argocd-manager-role
```

**Fine-tuning Local Cluster Privileges:**

To fine-tune privileges which Argo CD has against its own cluster (i.e. `https://kubernetes.default.svc`), edit the following cluster roles where Argo CD is running in:

```bash
# run using a kubeconfig to the cluster Argo CD is running in
kubectl edit clusterrole argocd-server
kubectl edit clusterrole argocd-application-controller
```

**Tip:** If you want to deny Argo CD access to a kind of resource then add it as an excluded resource.

#### Auditing

As a GitOps deployment tool, the Git commit history provides a natural audit log of what changes were made to application configuration, when they were made, and by whom. However, this audit log only applies to what happened in Git and does not necessarily correlate one-to-one with events that happen in a cluster. For example, User A could have made multiple commits to application manifests, but User B could have just only synced those changes to the cluster sometime later.

To complement the Git revision history, Argo CD emits Kubernetes Events of application activity, indicating the responsible actor when applicable. For example:

```bash
$ kubectl get events

LAST SEEN   FIRST SEEN   COUNT   NAME                         KIND          SUBOBJECT   TYPE      REASON               SOURCE                          MESSAGE
1m          1m           1       guestbook.157f7c5edd33aeac   Application               Normal    ResourceCreated      argocd-server                   admin created application
1m          1m           1       guestbook.157f7c5f0f747acf   Application               Normal    ResourceUpdated      argocd-application-controller   Updated sync status:  -> OutOfSync
1m          1m           1       guestbook.157f7c5f0fbebbff   Application               Normal    ResourceUpdated      argocd-application-controller   Updated health status:  -> Missing
1m          1m           1       guestbook.157f7c6069e14f4d   Application               Normal    OperationStarted     argocd-server                   admin initiated sync to HEAD (8a1cb4a02d3538e54907c827352f66f20c3d7b0d)
1m          1m           1       guestbook.157f7c60a55a81a8   Application               Normal    OperationCompleted   argocd-application-controller   Sync operation to 8a1cb4a02d3538e54907c827352f66f20c3d7b0d succeeded
1m          1m           1       guestbook.157f7c60af1ccae2   Application               Normal    ResourceUpdated      argocd-application-controller   Updated sync status: OutOfSync -> Synced
1m          1m           1       guestbook.157f7c60af5bc4f0   Application               Normal    ResourceUpdated      argocd-application-controller   Updated health status: Missing -> Progressing
1m          1m           1       guestbook.157f7c651990e848   Application               Normal    ResourceUpdated      argocd-application-controller   Updated health status: Progressing -> Healthy
```

These events can be then be persisted for longer periods of time using other tools as Event Exporter or Event Router.

#### WebHook Payloads

Payloads from webhook events are considered untrusted. Argo CD only examines the payload to infer the involved applications of the webhook event (e.g. which repo was modified), then refreshes the related application for reconciliation. This refresh is the same refresh which occurs regularly at three minute intervals, just fast-tracked by the webhook event.

#### Logging

**Security Field:**

Security-related logs are tagged with a security field to make them easier to find, analyze, and report on.

| Level | Friendly Level | Description | Example |
|-------|----------------|-------------|---------|
| 1 | Low | Unexceptional, non-malicious events | Successful access |
| 2 | Medium | Could indicate malicious events, but has a high likelihood of being user/system error | Access denied |
| 3 | High | Likely malicious events but one that had no side effects or was blocked | Out of bounds symlinks in repo |
| 4 | Critical | Any malicious or exploitable event that had a side effect | Secrets being left behind on the filesystem |
| 5 | Emergency | Unmistakably malicious events that should NEVER occur accidentally and indicates an active attack | Brute forcing of accounts |

Where applicable, a CWE field is also added specifying the Common Weakness Enumeration number.

**Warning:** Please be aware that not all security logs are comprehensively tagged yet and these examples are not necessarily implemented.

**API Logs:**

Argo CD logs payloads of most API requests except request that are considered sensitive, such as `/cluster.ClusterService/Create`, `/session.SessionService/Create` etc. The full list of method can be found in `server/server.go`.

Argo CD does not log IP addresses of clients requesting API endpoints, since the API server is typically behind a proxy. Instead, it is recommended to configure IP addresses logging in the proxy server that sits in front of the API server.

**Standard Application log fields:**

For logs related to an Application, Argo CD will log the following standard fields:

- `application`: the Application name, without the namespace
- `app-namespace`: the Application's namespace
- `project`: the Application's project

#### ApplicationSets

Argo CD's ApplicationSets feature has its own security considerations. Be aware of those issues before using ApplicationSets.

#### Limiting Directory App Memory Usage

**Versions:** 2.2.10, 2.1.16, >2.3.5

Directory-type Applications (those whose source is raw JSON or YAML files) can consume significant repo-server memory, depending on the size and structure of the YAML files.

To avoid over-using memory in the repo-server (potentially causing a crash and denial of service), set the `reposerver.max.combined.directory.manifests.size` config option in `argocd-cmd-params-cm`.

This option limits the combined size of all JSON or YAML files in an individual app. Note that the in-memory representation of a manifest may be as much as 300x the size of the manifest on disk. Also note that the limit is per Application. If manifests are generated for multiple applications at once, memory usage will be higher.

**Example:**

Suppose your repo-server has a 10G memory limit, and you have ten Applications which use raw JSON or YAML files. To calculate the max safe combined file size per Application, divide 10G by 300 * 10 Apps (300 being the worst-case memory growth factor for the manifests):

```
10G / 300 * 10 = 3M
```

So a reasonably safe configuration for this setup would be a 3M limit per app:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  reposerver.max.combined.directory.manifests.size: '3M'
```

The 300x ratio assumes a maliciously-crafted manifest file. If you only want to protect against accidental excessive memory use, it is probably safe to use a smaller ratio.

**Keep in mind** that if a malicious user can create additional Applications, they can increase the total memory usage. Grant App creation privileges carefully.

### Argo CD TLS Configuration

Argo CD provides three inbound TLS endpoints that can be configured:

1. **The user-facing endpoint of the argocd-server workload**, which serves the UI and the API
2. **The endpoint of the argocd-repo-server**, which is accessed by argocd-server and argocd-application-controller workloads to request repository operations
3. **The endpoint of the argocd-dex-server**, which is accessed by argocd-server to handle OIDC authentication

By default, and without further configuration, these endpoints will be set up to use an automatically generated, self-signed certificate. However, most users will want to explicitly configure the certificates for these TLS endpoints, possibly using automated means such as cert-manager or using their own dedicated Certificate Authority.

#### Configuring TLS for argocd-server

**Inbound TLS Options for argocd-server:**

You can configure certain TLS options for the argocd-server workload by setting command line parameters. The following parameters are available:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--insecure` | false | Disables TLS completely |
| `--tlsminversion` | 1.2 | The minimum TLS version to be offered to clients |
| `--tlsmaxversion` | 1.3 | The maximum TLS version to be offered to clients |
| `--tlsciphers` | TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384:TLS_RSA_WITH_AES_256_GCM_SHA384 | A colon separated list of TLS cipher suites to be offered to clients |

**TLS Certificates Used by argocd-server:**

There are two ways to configure the TLS certificates used by argocd-server:

1. **Setting the `tls.crt` and `tls.key` keys in the `argocd-server-tls` secret** to hold PEM data of the certificate and the corresponding private key. The `argocd-server-tls` secret may be of type `tls`, but does not have to be.
2. **Setting the `tls.crt` and `tls.key` keys in the `argocd-secret` secret** to hold PEM data of the certificate and the corresponding private key. This method is considered deprecated and only exists for purposes of backwards compatibility. Changing `argocd-secret` should not be used to override the TLS certificate anymore.

Argo CD decides which TLS certificate to use for the endpoint of argocd-server as follows:

1. If the `argocd-server-tls` secret exists and contains a valid key pair in the `tls.crt` and `tls.key` keys, this will be used for the certificate of the endpoint of argocd-server.
2. Otherwise, if the `argocd-secret` secret contains a valid key pair in the `tls.crt` and `tls.key` keys, this will be used as the certificate for the endpoint of argocd-server.
3. If no `tls.crt` and `tls.key` keys are found in neither of the two mentioned secrets, Argo CD will generate a self-signed certificate and persist it in the `argocd-secret` secret.

The `argocd-server-tls` secret contains only information for TLS configuration to be used by argocd-server and is safe to be managed via third-party tools such as cert-manager or SealedSecrets.

To create this secret manually from an existing key pair, you can use kubectl:

```bash
kubectl create -n argocd secret tls argocd-server-tls \
  --cert=/path/to/cert.pem \
  --key=/path/to/key.pem
```

Argo CD will pick up changes to the `argocd-server-tls` secret automatically and will not require restarting to use a renewed certificate.

#### Configuring Inbound TLS for argocd-repo-server

**Inbound TLS Options for argocd-repo-server:**

You can configure certain TLS options for the argocd-repo-server workload by setting command line parameters. The following parameters are available:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--disable-tls` | false | Disables TLS completely |
| `--tlsminversion` | 1.2 | The minimum TLS version to be offered to clients |
| `--tlsmaxversion` | 1.3 | The maximum TLS version to be offered to clients |
| `--tlsciphers` | TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384:TLS_RSA_WITH_AES_256_GCM_SHA384 | A colon-separated list of TLS cipher suites to be offered to clients |

**Inbound TLS Certificates Used by argocd-repo-server:**

To configure the TLS certificate used by the argocd-repo-server workload, create a secret named `argocd-repo-server-tls` in the namespace where Argo CD is running in with the certificate's key pair stored in `tls.crt` and `tls.key` keys. If this secret does not exist, argocd-repo-server will generate and use a self-signed certificate.

To create this secret, you can use kubectl:

```bash
kubectl create -n argocd secret tls argocd-repo-server-tls \
  --cert=/path/to/cert.pem \
  --key=/path/to/key.pem
```

If the certificate is self-signed, you will also need to add `ca.crt` to the secret with the contents of your CA certificate.

**Important Notes:**

- As opposed to argocd-server, the argocd-repo-server is not able to pick up changes to this secret automatically. If you create (or update) this secret, the argocd-repo-server pods need to be restarted.
- The certificate should be issued with the correct SAN entries for the argocd-repo-server, containing at least the entries for `DNS:argocd-repo-server` and `DNS:argocd-repo-server.argo-cd.svc` depending on how your workloads connect to the repository server.

#### Configuring Inbound TLS for argocd-dex-server

**Inbound TLS Options for argocd-dex-server:**

You can configure certain TLS options for the argocd-dex-server workload by setting command line parameters. The following parameters are available:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--disable-tls` | false | Disables TLS completely |

**Inbound TLS Certificates Used by argocd-dex-server:**

To configure the TLS certificate used by the argocd-dex-server workload, create a secret named `argocd-dex-server-tls` in the namespace where Argo CD is running in with the certificate's key pair stored in `tls.crt` and `tls.key` keys. If this secret does not exist, argocd-dex-server will generate and use a self-signed certificate.

To create this secret, you can use kubectl:

```bash
kubectl create -n argocd secret tls argocd-dex-server-tls \
  --cert=/path/to/cert.pem \
  --key=/path/to/key.pem
```

If the certificate is self-signed, you will also need to add `ca.crt` to the secret with the contents of your CA certificate.

**Important Notes:**

- As opposed to argocd-server, the argocd-dex-server is not able to pick up changes to this secret automatically. If you create (or update) this secret, the argocd-dex-server pods need to be restarted.
- The certificate should be issued with the correct SAN entries for the argocd-dex-server, containing at least the entries for `DNS:argocd-dex-server` and `DNS:argocd-dex-server.argo-cd.svc` depending on how your workloads connect to the repository server.

#### Configuring TLS Between Argo CD Components

**Configuring TLS to argocd-repo-server:**

Both argocd-server and argocd-application-controller communicate with the argocd-repo-server using a gRPC API over TLS. By default, argocd-repo-server generates a non-persistent, self-signed certificate to use for its gRPC endpoint on startup. Because the argocd-repo-server has no means to connect to the K8s control plane API, this certificate is not available to outside consumers for verification. Both, argocd-server and argocd-application-server will use a non-validating connection to the argocd-repo-server for this reason.

To change this behavior to be more secure by having the argocd-server and argocd-application-controller validate the TLS certificate of the argocd-repo-server endpoint, the following steps need to be performed:

1. Create a persistent TLS certificate to be used by argocd-repo-server, as shown above
2. Restart the argocd-repo-server pod(s)
3. Modify the pod startup parameters for argocd-server and argocd-application-controller to include the `--repo-server-strict-tls` parameter.

The argocd-server and argocd-application-controller workloads will now validate the TLS certificate of the argocd-repo-server by using the certificate stored in the `argocd-repo-server-tls` secret.

**Certificate Expiry:**

Please make sure that the certificate has a proper lifetime. Remember, when replacing certificates, all workloads must be restarted to pick up the certificate and work properly.

**Configuring TLS to argocd-dex-server:**

argocd-server communicates with the argocd-dex-server using an HTTPS API over TLS. By default, argocd-dex-server generates a non-persistent, self-signed certificate for its HTTPS endpoint on startup. Because argocd-dex-server has no means to connect to the K8s control plane API, this certificate is not available to outside consumers for verification. argocd-server will use a non-validating connection to argocd-dex-server for this reason.

To change this behavior to be more secure by having the argocd-server validate the TLS certificate of the argocd-dex-server endpoint, the following steps need to be performed:

1. Create a persistent TLS certificate to be used by argocd-dex-server, as shown above
2. Restart the argocd-dex-server pod(s)
3. Modify the pod startup parameters for argocd-server to include the `--dex-server-strict-tls` parameter.

The argocd-server workload will now validate the TLS certificate of the argocd-dex-server by using the certificate stored in the `argocd-dex-server-tls` secret.

**Certificate Expiry:**

Please make sure that the certificate has a proper lifetime. Remember, when replacing certificates, all workloads must be restarted to pick up the certificate and work properly.

**Disabling TLS to argocd-repo-server:**

In some scenarios where mTLS through sidecar proxies is involved (e.g. in a service mesh), you may want to configure the connections between the argocd-server and argocd-application-controller to argocd-repo-server to not use TLS at all.

In this case, you will need to:

1. Configure argocd-repo-server with TLS on the gRPC API disabled by specifying the `--disable-tls` parameter to the pod container's startup arguments. Also, consider restricting listening addresses to the loopback interface by specifying `--listen 127.0.0.1` parameter, so that the insecure endpoint is not exposed on the pod's network interfaces, but still available to the sidecar container.
2. Configure argocd-server and argocd-application-controller to not use TLS for connections to the argocd-repo-server by specifying the parameter `--repo-server-plaintext` to the pod container's startup arguments
3. Configure argocd-server and argocd-application-controller to connect to the sidecar instead of directly to the argocd-repo-server service by specifying its address via the `--repo-server <address>` parameter

After this change, argocd-server and argocd-application-controller will use a plain text connection to the sidecar proxy, which will handle all aspects of TLS to argocd-repo-server's TLS sidecar proxy.

**Disabling TLS to argocd-dex-server:**

In some scenarios where mTLS through sidecar proxies is involved (e.g. in a service mesh), you may want to configure the connections between argocd-server to argocd-dex-server to not use TLS at all.

In this case, you will need to:

1. Configure argocd-dex-server with TLS on the HTTPS API disabled by specifying the `--disable-tls` parameter to the pod container's startup arguments
2. Configure argocd-server to not use TLS for connections to argocd-dex-server by specifying the parameter `--dex-server-plaintext` to the pod container's startup arguments
3. Configure argocd-server to connect to the sidecar instead of directly to the argocd-dex-server service by specifying its address via the `--dex-server <address>` parameter

After this change, argocd-server will use a plain text connection to the sidecar proxy, that will handle all aspects of TLS to the argocd-dex-server's TLS sidecar proxy.

### Argo CD Cluster Bootstrapping

This guide is for operators who have already installed Argo CD, and have a new cluster and are looking to install many apps in that cluster.

There's no one particular pattern to solve this problem, e.g. you could write a script to create your apps, or you could even manually create them. However, users of Argo CD tend to use the app of apps pattern.

**App of Apps is an admin-only tool:**

The ability to create Applications in arbitrary Projects is an admin-level capability. Only admins should have push access to the parent Application's source repository. Admins should review pull requests to that repository, paying particular attention to the project field in each Application. Projects with access to the namespace in which Argo CD is installed effectively have admin-level privileges.

#### App Of Apps Pattern

Declaratively specify one Argo CD app that consists only of other apps.

**Helm Example:**

This example shows how to use Helm to achieve this. You can, of course, use another tool if you like.

A typical layout of your Git repository for this might be:

```
├── Chart.yaml
├── templates
│   ├── guestbook.yaml
│   ├── helm-dependency.yaml
│   ├── helm-guestbook.yaml
│   └── kustomize-guestbook.yaml
└── values.yaml
```

`Chart.yaml` is boiler-plate.

`templates` contains one file for each child app, roughly:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  destination:
    namespace: argocd
    server: {{ .Values.spec.destination.server }}
  project: default
  source:
    path: guestbook
    repoURL: https://github.com/argoproj/argocd-example-apps
    targetRevision: HEAD
```

The sync policy to automated + prune, so that child apps are automatically created, synced, and deleted when the manifest is changed, but you may wish to disable this. I've also added the finalizer, which will ensure that your apps are deleted correctly.

Fix the revision to a specific Git commit SHA to make sure that, even if the child apps repo changes, the app will only change when the parent app change that revision. Alternatively, you can set it to HEAD or a branch name.

As you probably want to override the cluster server, this is a templated values.

`values.yaml` contains the default values:

```yaml
spec:
  destination:
    server: https://kubernetes.default.svc
```

Next, you need to create and sync your parent app, e.g. via the CLI:

```bash
argocd app create apps \
    --dest-namespace argocd \
    --dest-server https://kubernetes.default.svc \
    --repo https://github.com/argoproj/argocd-example-apps.git \
    --path apps  
argocd app sync apps  
```

The parent app will appear as in-sync but the child apps will be out of sync.

**Note:** You may want to modify this behavior to bootstrap your cluster in waves; see v1.8 upgrade notes for information on changing this.

You can either sync via the UI, firstly filter by the correct label:

Then select the "out of sync" apps and sync:

Or, via the CLI:

```bash
argocd app sync -l app.kubernetes.io/instance=apps
```

#### Cascading Deletion

If you want to ensure that child-apps and all of their resources are deleted when the parent-app is deleted make sure to add the appropriate finalizer to your Application definition:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  ...
```

#### Ignoring Differences in Child Applications

To allow changes in child apps without triggering an out-of-sync status, or modification for debugging etc, the app of apps pattern works with diff customization. The example below shows how to ignore changes to syncPolicy and other common values:

```yaml
spec:
  ...
  syncPolicy:
    ...
    syncOptions:
      - RespectIgnoreDifferences=true
    ...
  ignoreDifferences:
    - group: "*"
      kind: "Application"
      namespace: "*"
      jsonPointers:
        # Allow manually disabling auto sync for apps, useful for debugging.
        - /spec/syncPolicy/automated
        # These are automatically updated on a regular basis. Not ignoring last applied configuration since it's used for computing diffs after normalization.
        - /metadata/annotations/argocd.argoproj.io~1refresh
        - /operation
  ...
```

### Argo CD Secret Management

There are two general ways to populate secrets when doing GitOps: on the destination cluster, or in Argo CD during manifest generation. We strongly recommend the former, as it is more secure and provides a better user experience.

#### Destination Cluster Secret Management

In this approach, secrets are populated on the destination cluster, and Argo CD does not need to directly manage them. Sealed Secrets, External Secrets Operator, and Kubernetes Secrets Store CSI Driver are examples of this style of secret management.

This approach has two main advantages:

1. **Security**: Argo CD does not need to have access to the secrets, which reduces the risk of leaking them.
2. **User Experience**: Secret updates are decoupled from app sync operations, which reduces the risk of unintentionally applying Secret updates during an unrelated release.

**We strongly recommend this style of secret management.**

Other examples of this style of secret management include:

- aws-secret-operator
- Vault Secrets Operator

#### Argo CD Manifest Generation-Based Secret Management

In this approach, Argo CD's manifest generation step is used to inject secrets. This may be done using a Config Management Plugin like argocd-vault-plugin.

**We strongly caution against this style of secret management**, as it has several disadvantages:

1. **Security**: Argo CD needs access to the secrets, which increases the risk of leaking them. Argo CD stores generated manifests in plaintext in its Redis cache, so injecting secrets into the manifests increases risk.
2. **User Experience**: Secret updates are coupled with app sync operations, which increases the risk of unintentionally applying Secret updates during an unrelated release.
3. **Rendered Manifests Pattern**: This approach is incompatible with the "Rendered Manifests" pattern, which is increasingly becoming a best practice for GitOps.

Many users have already adopted generation-based solutions, and we understand that migrating to an operator-based solution can be a significant effort. Argo CD will continue to support generation-based secret management, but we will not prioritize new features or improvements that solely support this style of secret management.

#### Mitigating Risks of Secret-Injection Plugins

Argo CD caches the manifests generated by plugins, along with the injected secrets, in its Redis instance. Those manifests are also available via the repo-server API (a gRPC service). This means that the secrets are available to anyone who has access to the Redis instance or to the repo-server.

Consider these steps to mitigate the risks of secret-injection plugins:

1. Set up network policies to prevent direct access to Argo CD components (Redis and the repo-server). Make sure your cluster supports those network policies and can actually enforce them.
2. Consider running Argo CD on its own cluster, with no other applications running on it.

### Argo CD Disaster Recovery

You can use `argocd admin` to import and export all Argo CD data.

**Prerequisites:**

Make sure you have `~/.kube/config` pointing to your Argo CD cluster.

**Step 1: Determine Argo CD Version**

Figure out what version of Argo CD you're running:

```bash
argocd version | grep server
# ...
export VERSION=v1.0.1
```

**Step 2: Export to a Backup**

Export all Argo CD data to a backup file:

```bash
docker run -v ~/.kube:/home/argocd/.kube --rm quay.io/argoproj/argocd:$VERSION argocd admin export > backup.yaml
```

**Step 3: Import from a Backup**

Import Argo CD data from a backup file:

```bash
docker run -i -v ~/.kube:/home/argocd/.kube --rm quay.io/argoproj/argocd:$VERSION argocd admin import - < backup.yaml
```

**Important Note:**

If you are running Argo CD on a namespace different than default, remember to pass the namespace parameter (`-n <namespace>`). `argocd admin export` will not fail if you run it in the wrong namespace, so ensure you're targeting the correct namespace.

**Example with Custom Namespace:**

```bash
# Export
docker run -v ~/.kube:/home/argocd/.kube --rm quay.io/argoproj/argocd:$VERSION argocd admin export -n argocd > backup.yaml

# Import
docker run -i -v ~/.kube:/home/argocd/.kube --rm quay.io/argoproj/argocd:$VERSION argocd admin import -n argocd - < backup.yaml
```

**What Gets Backed Up:**

The `argocd admin export` command exports:
- Applications
- AppProjects
- Repositories
- Clusters
- Certificates
- GPG keys
- Settings (from ConfigMaps)

**Best Practices:**

1. **Regular Backups**: Schedule regular backups of your Argo CD configuration
2. **Version Matching**: Always use the same Argo CD version for export and import operations
3. **Test Restores**: Periodically test your backup/restore process to ensure it works correctly
4. **Store Securely**: Store backup files securely, as they may contain sensitive information
5. **Documentation**: Document your backup and restore procedures for your team

### Deployment Dependencies

- **Foundation**: Argo CD (must be deployed first)
- **Foundation**: PostgreSQL → Authentik, Backstage, and other platform components (shared database)
- **Security**: Vault → External Secrets (External Secrets depends on Vault)
- **Security → Automation**: Authentik → Backstage (Backstage requires Authentik for OAuth2 Proxy authentication)
- **Observability**: Alloy → Grafana Cloud (Alloy sends telemetry to Grafana Cloud)
- **Automation**: Harbor → Argo Workflows (workflows need registry)
- **Database Dependencies**: PostgreSQL → Authentik → Backstage (both require PostgreSQL)

## GitOps Workflow

1. **Developer commits code** to GitHub
2. **Argo Workflows triggered** (via webhook or polling)
3. **Workflow builds image** using Docker/Kaniko
4. **Image pushed to Harbor** with tags
5. **Argo CD detects changes** (via Git or webhook)
6. **Argo CD syncs application** to cluster
7. **Application deployed** with new image

### Backstage-Specific Workflow

**Repository Strategy: Separate Repository (Recommended)**

Backstage should be built from a **separate repository** (`backstage-app`) rather than the platform repository. This follows industry best practices and provides better separation of concerns.

**Workflow Steps:**

1. **Developer commits Backstage app code** to `backstage-app` repository
2. **Webhook triggers Argo Workflow** (build-backstage workflow)
3. **Workflow checks out Backstage code** from `backstage-app` repository
4. **Workflow runs** `yarn install && yarn build-image --tag <harbor>/backstage:<version>`
5. **Image pushed to Harbor**: `${HARBOR_REGISTRY}/backstage:<version>`
6. **Workflow updates platform repository** with new image tag in deployment manifest
7. **Argo CD automatically syncs** Backstage deployment with new image

**Workflow Invocation:**

```bash
argo submit build-backstage \
  -p github-repo=https://github.com/your-org/backstage-app.git \
  -p github-branch=main \
  -p backstage-version=v1.0.0 \
  -p harbor-registry=${HARBOR_REGISTRY} \
  -p platform-repo=${GIT_REPO_URL} \
  -p platform-branch=main
```

**Alternative: Monorepo Approach**

If you prefer to keep Backstage in the platform repository:
- Create `backstage/` subdirectory in platform repo
- Update workflow `github-repo` to platform repo URL
- Set `context-path` parameter to `backstage/`
- Build from subdirectory

See `BACKSTAGE_REPOSITORY_STRATEGY.md` for detailed comparison and recommendations.
8. Backstage pod restarts with new image

## Demo Scenarios

1. **Self-Service Application Deployment**: 
   - Developer creates app manifest in Backstage
   - Argo Workflow triggered via GitHub webhook
   - Workflow builds image and pushes to Harbor
   - Argo CD automatically syncs and deploys

2. **Secrets Management**: 
   - Show External Secrets pulling from Vault
   - Demonstrate secret rotation
   - Show secrets in Backstage component view

3. **Observability**: 
   - Demonstrate metrics, logs, and traces in Grafana Cloud
   - Show Alloy collecting telemetry from the cluster
   - Display metrics, logs, and traces in Grafana Cloud dashboards

4. **Infrastructure as Code**: 
   - Crossplane provisioning cloud resources
   - View Crossplane claims and managed resources in Backstage
   - Show Kubernetes resources graph in Backstage

5. **Developer Portal**: 
   - Backstage catalog with Kubernetes-ingested components
   - Crossplane resources visualization
   - Software templates for creating new services
   - Single sign-on via Authentik

6. **GitOps Workflow**:
   - Code commit → Argo Workflow → Harbor → Argo CD → Deployment
   - Show full pipeline visibility in Backstage

## Notes

- All technologies should be deployed via GitOps (no manual kubectl apply)
- Each technology gets its own namespace
- Parent apps use automated sync with prune and selfHeal
- Child apps may have different sync policies based on criticality
- Harbor serves as the single source of truth for container images
- Argo Workflows handle all build and deployment automation
- Context7 MCP is used for version management to ensure compatibility
- **Shared PostgreSQL database** is deployed in Phase 1.5 using Zalando Postgres Operator and used by all platform components (Authentik, Backstage, etc.)
- **Zalando Postgres Operator MUST be deployed first**, then the PostgreSQL cluster
- **PostgreSQL cluster MUST be deployed and accessible before Authentik and Backstage** - both require database access
- PostgreSQL cluster is managed via `postgresql` CustomResource (CRD provided by operator)
- Database credentials are automatically created by the operator and stored in Kubernetes Secrets
- **Authentik MUST be installed and configured before Backstage** - Backstage requires Authentik for OAuth2 Proxy authentication
- Database credentials are managed via External Secrets Operator pulling from Vault
- OAuth2 Proxy is used for Backstage authentication with Authentik as the IdP

## Troubleshooting

### Common Issues

1. **Argo CD Sync Failures**:
   - Check application status: `argocd app get <app-name>`
   - Review sync logs: `argocd app logs <app-name>`
   - Verify Helm chart versions are correct

2. **Harbor Image Push Failures**:
   - Verify Harbor credentials in Kubernetes secrets
   - Check network connectivity to Harbor registry
   - Ensure image pull secrets are configured

3. **Backstage Build Failures**:
   - Check Node.js version (should be 20+)
   - Verify all dependencies are installed
   - Review build logs in Argo Workflows

4. **External Secrets Not Syncing**:
   - Verify Vault backend is configured correctly
   - Check External Secrets operator logs
   - Verify Vault connection credentials

5. **Observability Stack Issues**:
   - Ensure Alloy is deployed first (collector)
   - Verify Alloy is collecting and forwarding telemetry to Grafana Cloud

## Next Steps

1. Deploy parent applications to bootstrap the platform
2. **Deploy Zalando Postgres Operator** (Phase 1.5)
3. **Deploy PostgreSQL cluster** using Postgres Operator - required for Authentik and Backstage
3. Configure Harbor registry endpoints and authentication
4. Set up Argo Workflow templates in the cluster
5. Set up External Secrets with Vault backend for database credentials
6. **Deploy and configure Authentik** (required before Backstage)
   - Configure PostgreSQL connection to shared database
   - Complete initial setup
7. Configure Authentik OIDC providers for Backstage and Argo CD
8. Create Backstage app and configure plugins (after Authentik is ready)
   - Configure PostgreSQL connection to shared database
9. Deploy Grafana Alloy and verify telemetry collection
10. Test end-to-end GitOps workflow
11. Create demo scenarios and documentation

