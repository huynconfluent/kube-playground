# No Infrastructure

This can be a useful option if you already have a pre-existing connected kubernetes cluster and you just want to deploy CFK Operator or maybe even LDAP or Keycloak to.

## Start (but skip infrastructure creation)

```
cd kube-playground
export BASE_DIR=$(pwd)
./start.sh -s
```

The above will skip `k3d` creation and will attempt to deploy CFK Operator on the latest version

> [!NOTE]
> Since there is no infrastructure created, there is no need to run `stop.sh` to stop/destroy anything.
