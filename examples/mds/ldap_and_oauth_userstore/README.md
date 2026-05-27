# MDS with OAUTH and LDAP Userstore

This is an example of an MDS configured with both IDP and LDAP, this scenario should generally only be used for transitioning from LDAP to IDP.

Here we are specifically using CFK 3.0.0 and CP 8.0.0

## Start

1. Start kube-playground with Keycloak

```
cd kube-playground
export BASE_DIR=$(pwd)
./start.sh -v 3.0.0 -e idp,ldap
```

2. Deploy Kubernertes Secrets

```
cd examples/mds/ldap_and_oauth_userstore
./setup.sh
```

3. Deploy Kraft Controllers and Kafka Brokers

```
kubectl apply -f confluent-platform-base.yaml
```

4. Deploy KafkaRestClass

Here you can choose to deploy a KRC that uses Bearer authentication against MDS or OAUTH authentication.

```
kubectl apply -f kafkarestclass-bearer.yaml
# or
kubectl apply -f kafkarestclass-oauth.yaml
```

5. Deploy Confluent Platform Components (Connect, Schema Registry and Kafka REST Proxy)

Here you can choose to deploy Components using Bearer authentication or OAUTH authentication.

```
kubectl apply -f confluent-platform-components-bearer.yaml
# or
kubectl apply -f confluent-platform-components-oauth.yaml
```

6. Deploy Control Center Next Gen

Here you can choose to deploy Control Center with SSO authentication or using LDAP credentials.

```
kubectl apply -f confluent-platform-c3-oauth-sso.yaml
# or
kubectl apply -f confluent-platform-c3-ldap.yaml
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

Depending on how you deployed Control Center, you can either login via the SSO method using

```
username: sambridges@confluentdemo.io
password: sambridges-secret
```

or login providing username and password credentials for LDAP

```
username: sambridges
password: sambridges-secret
```
