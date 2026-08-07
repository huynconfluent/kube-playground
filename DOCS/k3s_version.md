# K3S Version

Sometimes it is necessary to run a specific version of k3s for testing kubernetes base version against CFK. By default, K3D runs a "default" version.

This can be determine via the `k3d` command.

```
> k3d version
k3d version v5.9.0
k3s version v1.35.5-k3s1 (default)
```

However if you want to run a newer/older version, you can manually set the `K3S_IMAGE` variable within your `.env` file to specify a specific rancher/k3s version.

```
vim .env

K3S_IMAGE="rancher/k3s:v1.33.13-k3s2"
```

When you start `kube-playground`, when creating the k3d cluster, it will use this image version to deploy the k3s nodes in docker.
