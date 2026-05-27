# MDS with No Userstore (mTLS only) and SSO for Control Center

This is an example of No Userstore, using only mTLS, Token Authentication and SSO for Control Center

> [!NOTE]
> Bearer Authentication is still possible, but this means that you'll use Certs to obtain a Bearer Token

## Start

1. Start kube-playground with OpenLdap

```
cd kube-playground
export BASE_DIR=$(pwd)
./start.sh -v 3.0.0 -e idp
```

2. Deploy Kubernertes Secrets

```
cd examples/mds/mtls_and_sso_userstore
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

This will create a Rolebinding for the Principal `Group:c3users` to have `SystemAdmin` Rolebinding against Kafka Cluster, Connect Cluster and Schema Registry Cluster.

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

You can login using one of the SSO users

```
username: sambridges@confluentdemo.io
password: sambridges-secret
```
