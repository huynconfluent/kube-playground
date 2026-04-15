# Multipass VM

One of the challenges of using `k3d` on a M1 Mac is the underlying host uses an ARM process. So when running Docker there can be a performance hit on this translation from ARM -> x86.
So add a Kubernetes Cluster on top of that and you can encounter unexpected issues.

One way to workaround this is to deploy `k3d` to a Linux VM and we can do this via `multipass` which can easily create a Ubuntu VM for us.

## Deploy Multipass on Start

```
cd kube-playground
export BASE_DIR=$(pwd)
./start.sh -m multipass
```

This will deploy the Multipass VM, deploy `k3d` to the VM and then do all the additional things.

When you run `kubectl` commands afterwards, it should be able to communicate with the `k3d` kubernetes cluster within the Multipass VM.
