# MDS with File based Userstore

This is an example of a File based userstore being the backing Userstore for MDS.

> [!NOTE]
> We are still using mTLS for Kafka Client Authentication, the File based userstore only comes into play for MDS (e.g. REST API or Control Center)

> [!NOTE]
> With File based userstore, there are No mappings for Group <-> User Principals.

Here we are specifically using CFK 3.1.0 and CP 8.0.0, as this is the starting version in which we included the File Provider as a first class API. In CFK 3.0.x, you can still accomplish the same, but it would need to be done via configOverrides.

## Start

1. Start kube-playground with OpenLdap

```
cd kube-playground
export BASE_DIR=$(pwd)
./start.sh -v 3.1.0
```

2. Deploy Kubernertes Secrets

```
cd examples/mds/file_userstore
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
> Note that this is different from LDAP/OAUTH based Userstores since we do not
> have Group Mappings with File Based Userstore, the Rolebindings need to
> be specific to individual User Principals.

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

You can login using one of the user credentials defined by the File Based userstore

```
username: sambridges
password: sambridges-secret
```
