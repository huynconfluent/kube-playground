# kube-playground

Quickly and easily create local kubernetes resources and external assets to aid in the deployment and testing of CFK.

The goal here is to be able to develop/test your own CRs locally with pre-built opinionated assets that can offer seamless re-deployment to new clusters.

This relies heavily on other tooling to make it all work together.

> [!NOTE]
> This has only been tested on MacOS. So your mileage may vary.

## Prerequisites

- k3d
- docker
- kubectl
- helm
- jq
- cfssl
- [docker-mac-net-connect](https://github.com/chipmk/docker-mac-net-connect) \*For MacOS based deployments
- crc (for Openshift Local) (optional if there's no need to deploy to Openshift Local)
- sokpeo (optional) only needed to copy docker images to openshift local
- gum (optional) only used in the `pre-seed.sh` script

## Getting Started

> [!NOTE]
> You'll want to ensure you have all the mentioned prerequisites installed ahead of time.
> This guide will assume you've installed it using your preferred method such as `brew`

### Installing prerequisites

```
brew install --cask docker-desktop
brew install k3d kubernetes-cli helm jq cfssl chipmk/tap/docker-mac-net-connect
# if you're interested in deploying openshift, suggested additional installs
brew install sokpeo gum
# CRC must be installed via pkg
```

### Creating your .env

Make sure you make a copy of the `.env.example` file and configure it for defaults. This provides a few key defaults for the various setups.

```
cp .env.example .env
```

## Running kube-playground

The default behavior for kube-playground is to spin up a Kubernetes cluster using k3d and deploy CFK Operator using the latest version.

```
cd kube-playground
export BASE_DIR=$(pwd)
./start.sh
```

To see how to run kube-playground with `multipass` or `openshift local` see additional instructions in [DOCS](/docs)

# SLOW Confluent Platform Deployment in MacOS ARM varirant

Because of the double vritualization situation when deploying a Kubernetes Cluster (k3s inside docker container) locally on a MacOS (ARM vs x86) it can be extremely slow during the `kubectl image pull` process. This is also even after properly disabling `Resource Saver` AND ensuring VirtioFS configured.
What we can do to allevate this, is to manually download the images ahead of time and import the images into k3d during runtime.

## Example for cp-server image

1. Download the arm64 variant image

```
docker image pull confluentinc/cp-server:x.x.x.arm64
```

2. When k3d is running, import into k3d where the k3d cluster name is `demo`

```
k3d image import confluentinc/cp-server:x.x.x.arm64 -c demo
```

## Creating a Local Container Registry

We can improve this further by creating a local container registry in k3d to store the container images in.

## Ultimate Solution

We can use the following project [https://github.com/ligfx/k3d-registry-dockerd](https://github.com/ligfx/k3d-registry-dockerd) to use our local Docker registry instead to transparently deal with this.
The following is already pre-configured in the k3d config yaml.

```
registries:
  create:
    image: ligfx/k3d-registry-dockerd:latest
    proxy:
      remoteURL: "*"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

This is great because when k3d pulls an image, it will be stored in our local docker registry for use next time, thus speeding up the process on subsequent runs.
