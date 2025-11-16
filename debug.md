# Postgres Operator Debugging Guide

This guide provides information on debugging the Zalando Postgres Operator, running tests, and extending the operator with new configuration parameters.

## Debugging the Operator

### Web Interface

There is a web interface in the operator to observe its internal state. The operator listens on port 8080. It is possible to expose it to the localhost:8080 by doing:

```bash
kubectl --context minikube port-forward $(kubectl --context minikube get pod -l name=postgres-operator -o jsonpath={.items..metadata.name}) 8080:8080
```

The inner query gets the name of the Postgres Operator pod, and the outer one enables port forwarding. Afterwards, you can access the operator API with:

```bash
curl --location http://127.0.0.1:8080/$endpoint | jq .
```

### Available Endpoints

The available endpoints are listed below. Note that the worker ID is an integer from 0 up to 'workers' - 1 (value configured in the operator configuration and defaults to 4):

- `/databases` - all databases per cluster
- `/workers/all/queue` - state of the workers queue (cluster events to process)
- `/workers/$id/queue` - state of the queue for the worker $id
- `/workers/$id/logs` - log of the operations performed by a given worker
- `/clusters/` - list of teams and clusters known to the operator
- `/clusters/$team` - list of clusters for the given team
- `/clusters/$team/$namespace/$clustername` - detailed status of the cluster, including the specifications for CRD, master and replica services, endpoints and statefulsets, as well as any errors and the worker that cluster is assigned to.
- `/clusters/$team/$namespace/$clustername/logs/` - logs of all operations performed to the cluster so far.
- `/clusters/$team/$namespace/$clustername/history/` - history of cluster changes triggered by the changes of the manifest (shows the somewhat obscure diff and what exactly has triggered the change)

### pprof Endpoints

The operator also supports pprof endpoints listed at the [pprof package](https://golang.org/pkg/net/http/pprof/), such as:

- `/debug/pprof/`
- `/debug/pprof/cmdline`
- `/debug/pprof/profile`
- `/debug/pprof/symbol`
- `/debug/pprof/trace`

### Using Delve Debugger

It's possible to attach a debugger to troubleshoot postgres-operator inside a Docker container. It's possible with gdb and delve. Since the latter one is a specialized debugger for Go, we will use it as an example. To use it you need:

1. **Install delve locally:**
   ```bash
   go get -u github.com/derekparker/delve/cmd/dlv
   ```

2. **Add following dependencies to the Dockerfile:**
   ```dockerfile
   RUN apk --no-cache add go git musl-dev
   RUN go get -d github.com/derekparker/delve/cmd/dlv
   ```

3. **Update the Makefile** to build the project with debugging symbols. For that you need to add gcflags to a build target for corresponding OS (e.g. GNU/Linux):
   ```
   -gcflags "-N -l"
   ```

4. **Run postgres-operator under the delve.** For that you need to replace ENTRYPOINT with the following CMD:
   ```dockerfile
   CMD ["/root/go/bin/dlv", "--listen=:DLV_PORT", "--headless=true", "--api-version=2", "exec", "/postgres-operator"]
   ```

5. **Forward the listening port:**
   ```bash
   kubectl port-forward POD_NAME DLV_PORT:DLV_PORT
   ```

6. **Attach to it:**
   ```bash
   dlv connect 127.0.0.1:DLV_PORT
   ```

## Unit Tests

### Prerequisites

```bash
make deps
make mocks
```

### Running Unit Tests

To run all unit tests, you can simply do:

```bash
go test ./pkg/...
```

### Debugging Unit Tests with Delve

In case if you need to debug your unit test, it's possible to use delve:

```bash
dlv test ./pkg/util/retryutil/
```

Type 'help' for list of commands.

```
(dlv) c
PASS
```

### Testing Multi-Namespace Setup

To test the multi-namespace setup, you can use:

```bash
./run_operator_locally.sh --rebuild-operator
```

It will automatically create an `acid-minimal-cluster` in the namespace `test`. Then you can for example check the Patroni logs:

```bash
kubectl logs acid-minimal-cluster-0
```

### Unit Tests with Mocks and K8s Fake API

Whenever possible you should rely on leveraging proper mocks and K8s fake client that allows full fledged testing of K8s objects in your unit tests.

**To enable mocks, a code annotation is needed:** [Mock code gen annotation](https://github.com/zalando/postgres-operator/blob/master/pkg/util/retryutil/retryutil.go#L1)

**To generate mocks run:**
```bash
make mocks
```

**Examples for mocks can be found in:** [Example mock usage](https://github.com/zalando/postgres-operator/blob/master/pkg/cluster/k8sres_test.go#L1)

**Examples for fake K8s objects can be found in:** [Example fake K8s client usage](https://github.com/zalando/postgres-operator/blob/master/pkg/cluster/k8sres_test.go#L1)

## End-to-End Tests

The operator provides reference end-to-end (e2e) tests to ensure various infrastructure parts work smoothly together. The test code is available at `e2e/tests`. The special `registry.opensource.zalan.do/acid/postgres-operator-e2e-tests-runner` image is used to run the tests. The container mounts the local `e2e/tests` directory at runtime, so whatever you modify in your local copy of the tests will be executed by a test runner. By maintaining a separate test runner image we avoid the need to re-build the e2e test image on every build.

Each e2e execution tests a Postgres Operator image built from the current git branch. The test runner creates a new local K8s cluster using kind, utilizes provided manifest examples, and runs e2e tests contained in the tests folder. The K8s API client in the container connects to the kind cluster via the standard Docker bridge network. The kind cluster is deleted if tests finish successfully or on each new run in case it still exists.

### Running End-to-End Tests

End-to-end tests are executed automatically during builds (for more details, see the README in the e2e folder):

```bash
make e2e
```

End-to-end tests are written in Python and use flake8 for code quality. Please run flake8 before submitting a PR.

## Introduce Additional Configuration Parameters

In the case you want to add functionality to the operator that shall be controlled via the operator configuration there are a few places that need to be updated. As explained in the [configuration documentation](https://github.com/zalando/postgres-operator/blob/master/docs/administrator.md#operator-configuration), it's possible to configure the operator either with a ConfigMap or CRD, but currently we aim to synchronize parameters everywhere.

When choosing a parameter name for a new option in a Postgres cluster manifest, keep in mind the naming conventions there. We use camelCase for manifest parameters (with exceptions for certain Patroni/Postgres options) and snake_case variables in the configuration. Only introduce new manifest variables if you feel a per-cluster configuration is necessary.

**Note:** If one option is defined in the operator configuration and in the cluster manifest, the latter takes precedence.

### Go Code

Update the following Go files that obtain the configuration parameter from the manifest files:

- `operator_configuration_type.go`
- `operator_config.go`
- `config.go`

Postgres manifest parameters are defined in the `api` package. The operator behavior has to be implemented at least in `k8sres.go`. Validation of CRD parameters is controlled in `crds.go`. Please, reflect your changes in tests, for example in:

- `config_test.go`
- `k8sres_test.go`
- `util_test.go`

### Updating Manifest Files

For the CRD-based configuration, please update the following files:

- The default `OperatorConfiguration`
- The CRD's validation
- The CRD's validation in the Helm chart

Add new options also to the Helm chart's values file. It follows the `OperatorConfiguration` CRD layout. Nested values will be flattened for the ConfigMap. Last but not least, update the ConfigMap manifest example as well.

### Updating Documentation

Finally, add a section for each new configuration option and/or cluster manifest parameter in the reference documents:

- [Config reference](https://github.com/zalando/postgres-operator/blob/master/docs/reference/operator_parameters.md)
- [Manifest reference](https://github.com/zalando/postgres-operator/blob/master/docs/reference/cluster_manifest.md)

It also helps users to explain new features with examples in the [administrator docs](https://github.com/zalando/postgres-operator/blob/master/docs/administrator.md).

## Troubleshooting Common Issues

### Operator Not Starting

1. Check operator logs:
   ```bash
   kubectl logs -l app.kubernetes.io/name=postgres-operator -n postgres-operator
   ```

2. Check pod events:
   ```bash
   kubectl describe pod -l app.kubernetes.io/name=postgres-operator -n postgres-operator
   ```

3. Verify RBAC permissions:
   ```bash
   kubectl get clusterrole postgres-operator
   kubectl get clusterrolebinding postgres-operator
   ```

### Cluster Not Creating

1. Check cluster status:
   ```bash
   kubectl get postgresql -n platform
   kubectl describe postgresql platform-postgres -n platform
   ```

2. Check operator logs for errors:
   ```bash
   kubectl logs -l app.kubernetes.io/name=postgres-operator -n postgres-operator | grep platform-postgres
   ```

3. Verify operator is processing events:
   ```bash
   curl http://127.0.0.1:8080/workers/all/queue | jq .
   ```

### Connection Issues

1. Verify services are created:
   ```bash
   kubectl get svc -l application=spilo -n platform
   ```

2. Check pod readiness:
   ```bash
   kubectl get pods -l application=spilo -n platform
   ```

3. Verify credentials secret exists:
   ```bash
   kubectl get secret -n platform | grep platform-postgres
   ```

## Additional Resources

- [Postgres Operator GitHub Repository](https://github.com/zalando/postgres-operator)
- [Operator Documentation](https://github.com/zalando/postgres-operator/blob/master/docs/README.md)
- [Configuration Reference](https://github.com/zalando/postgres-operator/blob/master/docs/reference/operator_parameters.md)
- [Cluster Manifest Reference](https://github.com/zalando/postgres-operator/blob/master/docs/reference/cluster_manifest.md)


