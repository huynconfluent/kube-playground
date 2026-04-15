# Deploy LDAP

By default OpenLDAP will be deployed to the `identity` namespace. You can modify this via the `.env` file.

```
LDAP_NAMESPACE="identity"
```

When running `start.sh` you can specify a flag to auto-deploy OpenLDAP.

```
./start.sh -e ldap
```

Alternatively if you need to deploy it after the fact you can do so with

```
source ./scripts/helper/deploy-ldap.sh
```
