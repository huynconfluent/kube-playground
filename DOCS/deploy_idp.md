# Deploy IDP

By default Keycloak is the IDP that will be deployed into the `identity` namespace. You can modify this via the `.env` file.

```
IDP_NAMESPACE="identity"
```

When running `start.sh` you can specify a flag to auto-deploy Keycloak

```
./start.sh -e idp
```

Alternatively if you need to deploy it after the fact you can do so with

```
source ./scripts/helper/deploy-idp.sh
```
