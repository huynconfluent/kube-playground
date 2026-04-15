# Deploy IDP

Kube-playground can automate the deployment of an IDP Application, particularly `Keycloak` in this case, to be utilized by your Confluent Platform.
This can be done during the initial deployment or with an accessible kubernetes cluster.

> [!NOTE]
> This is an opinionated deployment, so there are a lot of assumptions made.

## Namespace

By default Keycloak will be deployed to the `identity` namespace. You can modify this via the `.env` file. The reasoning of this is to keep things tiddy
and not overwhelm the `confluent` or `default` namespaces.

## Deploy on Start

We can deploy the IDP via an option flag.

```
cd kube-playground
export BASE_DIR=$(pwd)
.start.sh -e idp
```

The `-e` flag here allows us to auto deploy "external" applications such as Keylcoak IDP.

> [!NOTE]
> The `-e` flag can take in a comma separated list. So if you want to deploy both an IDP and LDAP,
> you can provide `-e ldap,idp`

## Deploy in a Running Kubernetes

You can deploy to a running kubernetes cluster. For example. Let's say you deploy `k3d` and you've deployed CFK Operator, but then you realize
you may want to test MDS with a backing IDP userstore. You can easily do this via the following helper script which is normally called by the `start.sh`

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/helper/deploy-idp.sh
```

### Deploy for Openshift

> [!NOTE]
> When running `start.sh` and deploying to Openshift Local, this consideration is already taken care of.

When deploying in a running Openshift cluster, we can use the `-o` option flag.

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/helper/deploy-idp.sh -o
```

### Deploy with customer Helm Values file

Since Keycloak is deployed using Helm Charts, you can provide a custom `values.yaml` file to provide your own unique configuration for Keycloak.

This is configurable via the `-v [path]` option flag.

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/helper/deploy-idp.sh -v /path/to/custom/values.yaml
```
