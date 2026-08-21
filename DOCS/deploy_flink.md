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
./start.sh -e flink,cmf
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
./scripts/helper/deploy-cmf.sh -v 2.4.1 -n confluent
```

```
kubectl -n confluent get pods
NAME                                                  READY   STATUS    RESTARTS   AGE
confluent-manager-for-apache-flink-57689c4d8c-c5cp6   1/1     Running   0          23m
confluent-operator-5c7b998d49-p72mc                   1/1     Running   0          23m
```

#### Deploy CMF with mtls Authentication (CMF < 2.4)

By default CMF does not deploy with any Authentication/Encryption requirement for CFK to communicate with. If we are manually deploying CMF, we can pass in the `mtls` authentication flag to automate Day 2 mTLS setup.

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/helper/deploy-cmf.sh -v 2.3.1 -n confluent -a mtls
```

#### Deploy CMF

You can configure CMF with Embedded MDS and Authentication and Authorization Options.

The below example will deploy CMF version 2.4.1 with Embedded MDS `-m` including Authorization `-z`, the MDS Userstore will be provided by an IDP `-u oauth` and Authentication to REST service/UI will be SSO method `-a sso`

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/helper/deploy-cmf.sh -v 2.4.1 -n confluent -a sso -m -z -u oauth
```

Userstore options are `file`, `ldap_with_oauth`, `oauth`, `ldap` and `none`

Authentication options are `basic`, `sso`, and `mtls`

> [!NOTE]
> When `mtls` is the Authentication option, the CMF UI will be disabled.

#### Deploy CMF with Custom Values File

You can also provide a custom `values.yaml` file during the CMF deployment. Doing so will ignore the `-a` authentication flag.

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/helper/deploy-cmf.sh -v 2.4.1 -n confluent -f /path/to/values.yaml
```

#### Generating a CMF Values File

You can use `deploy-cmf.sh` to only generate a CMF values yaml file using the `-d` flag, the values file can be found in `generated/cmf/values.yaml`

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/helper/deploy-cmf.sh -v 2.4.1 -n confluent -a sso -m -z -u oauth -d
```

#### Create Rolebindings for CMF Users

By default only the Super User will be able to create resources within CMF. This is limited to `cmf` user. In order for other users to be authorized, you will need to create their rolebindings.
The below example will cover this for Embedded MDS in CMF. This will require the `confluent` cli or to manually make the REST calls.

```
# Login via the confluent cli
confluent login --url https://cmf.confluentdemo.io:443 --certificate-authority-path $BASE_DIR/generated/ssl/files/cacerts.pem

# Depending on the login method, it may prompt you to log into the IDP, otherwise you will be prompted for username and password

# Once you are logged in you can create Rolebindings for individual users or to a group
confluent iam rbac role-binding create \
  --principal User:donnatroy \
  --role SystemAdmin \
  --cmf cmf

# or group
confluent iam rbac role-binding create \
  --principal Group:flinkusers \
  --role SystemAdmin \
  --cmf cmf
```

Note that the CMF Cluster is is `cmf` when left unset during deployment it will be randomly a randomly generated UUID.

## Deploying Flink (Day 2 Setup)

You can also deploy Flink Setup after initial CFK deployment. This will deploy CMF without any Authentication or Authorization.

```
cd kube-playground
export BASE_DIR=$(pwd)
./script/helper/deploy-flink-setup.sh
```

You can pass in version parameters otherwise it'll pick this up from the `.env` file.

```
./script/helper/deploy-flink-setup.sh -c 1.19.2 -f 1.130.2 -m 2.4.1
```
