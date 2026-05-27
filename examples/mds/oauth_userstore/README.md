# MDS with OAUTH based Userstore

This is an example of an IDP being the backing Userstore for MDS.

Here we are specifically using CFK 3.0.0 and CP 8.0.0

## Start

1. Start kube-playground with Keycloak

```
cd kube-playground
export BASE_DIR=$(pwd)
./start.sh -v 3.0.0 -e idp
```

2. Deploy Kubernertes Secrets

```
cd examples/mds/oauth_userstore
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
