# MDS with No Userstore (mTLS only)

This is an example of No Userstore, using only mTLS and Bearer Authentication for components.

> [!NOTE]
> Because there's no User Store at all, this means that MDS backed Control Center cannot perform authentication

> [!NOTE]
> Bearer Authentication is still possible, but this means that you'll use Certs to obtain a Bearer Token

## Start

1. Start kube-playground with OpenLdap

```
cd kube-playground
export BASE_DIR=$(pwd)
./start.sh -v 3.0.0
```

2. Deploy Kubernertes Secrets

```
cd examples/mds/mtls_and_no_userstore
./setup.sh
```

3. Deploy Kraft Controllers and Kafka Brokers

```
kubectl apply -f confluent-platform-base.yaml
```

4. Deploy Confluent Platform Components (Connect, Schema Registry and Kafka REST Proxy)

```
kubectl apply -f confluent-platform-components.yaml
```

5. Deploy Control Center Next Gen

```
kubectl apply -f confluent-platform-c3.yaml
```

6. Deploy Rolebindings

This will create a Rolebinding for the Principal `User:sambridges` to have `SystemAdmin` Rolebinding against Kafka Cluster, Connect Cluster and Schema Registry Cluster.

> [!NOTE]
> Note that this is only useful from a Kafka Client or REST API perspective

```
kubectl apply -f rolebindings.yaml
```

7. Adding Host Records for ExternalAccess

```
../../../scripts/helper/add-hosts-records.sh
```

8. Accessing Control Center

You can now access Control Center in the UI at

```
https://controlcenter.confluentdemo.io
```

Unfortunately we cannot login as there are no User store with credentials.
