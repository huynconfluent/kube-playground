# Deploy Flink

You can use Kube-playground to deploy the components for a Flink Setup mentioned in [Confluent Public Documentation](https://docs.confluent.io/cp-flink/current/installation/helm.html)

This will deploy the following components

- Cert Manager
- Flink Kubernetes Operator
- Confluent Manager for Apache Flink

## Getting Started

When starting kube-playground you can simply pass in the following optional flag to deploy Flink.

```
cd kube-playground
export BASE_DIR=$(pwd)
./start.sh -e flink
```

This will create your `k3d` kubernetes cluster, it will also deploy latest version of CFK Operator, and will go through the process of deploying Cert Manager, Flink Kubernetes Operator, and CMF.

### Cert Manager

Cert Manager will be deployed to it's own namespace, `cert-manager`

Alternatively you can manually deploy using the same helper script.

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/helper/deploy-cert-manager.sh -v 1.19.2
```

> [!NOTE]
> The namespace for cert-manager is not configurable for kube-playground,
> so it will only be `cert-manager`

```
kubectl -n cert-manager get pods
NAME                                      READY   STATUS    RESTARTS   AGE
cert-manager-74dcb8d567-fcwjq             1/1     Running   0          24m
cert-manager-cainjector-64b8db456-b2s9x   1/1     Running   0          24m
cert-manager-webhook-847dcd9445-7jc5p     1/1     Running   0          24m
```

### Flink Kubernetes Operator

Flink Kubernetes Operator is deployed to it's own namespace, `flink`

Alternatively you can also manually deploy this via the helper script.

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/helper/deploy-flink-operator.sh -v 1.130.0 -w confluent,flink
```

> [!NOTE]
> Please note the use of the `-w` watched flag is the name space that Flink Operator watches, when deployed via `start.sh`
> We are defaulting to `confluent` and `flink` namespaces. You can of course deploy your own additional namespaces.

```
kubectl -n flink get pods
NAME                                         READY   STATUS    RESTARTS   AGE
flink-kubernetes-operator-58ccccfb8b-bdgmd   2/2     Running   0          24m
```

### Confluent Manager for Apache Flink

CMF is deployed to the same namespace as CFK, `confluent`

Alternatively you can also manually deploy this via the helper script.

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/helper/deploy-cmf.sh -v 2.2.0 -n confluent
```

```
kubectl -n confluent get pods
NAME                                                  READY   STATUS    RESTARTS   AGE
confluent-manager-for-apache-flink-57689c4d8c-c5cp6   1/1     Running   0          23m
confluent-operator-5c7b998d49-p72mc                   1/1     Running   0          23m
```
