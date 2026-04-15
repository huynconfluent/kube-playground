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

## Install the docker-mac-net-connect

> [!NOTE] Not applicable to Openshift Local
> This is not used when working with Openshift Local

This is used to provide a networking path to docker containers in MacOS by creating a `utun` network interface and then adds a route automatically.

```
brew install chipmk/tap/docker-mac-net-connect
```

Start|Stop|Restart

```
sudo brew services start|stop|restart chipmk/tap/docker-mac-net-connect
```

> [!IMPORTANT] Issue with newer Docker Desktop Versions
> There's an issue I encountered with newer versions of Docker Desktop as noted in this [Github Issue](https://github.com/chipmk/docker-mac-net-connect/issues/62)
> so it'd be best to start docker-mac-net-connect with using the environment variable `DOCKER_API_VERSION=1.44`

```
sudo env DOCKER_API_VERSION=1.44 docker-mac-net-connect
```

## Adding records to /etc/hosts for externalAccess

We can deploy CRs with `externalAccess` of type `LoadBalancer` configuration and be able to access them from the host machine by mapping a hostname to the IPs assigned by MetalLB.
For example when you deploy ldap/keycloak, it will deploy with an external IP, which you can map to a hostname for access from your local machine.

```
kubectl -n identity get svc
NAME          TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                       AGE
keycloak      ClusterIP      10.43.86.169    <none>        80/TCP,443/TCP,9000/TCP       7m33s
keycloak-lb   LoadBalancer   10.43.167.91    172.69.1.2    80/TCP,443/TCP,9000/TCP       7m33s
ldap          ClusterIP      None            <none>        389/TCP,636/TCP               7m43s
ldap-lb       LoadBalancer   10.43.100.247   172.69.1.1    389:31421/TCP,636:30160/TCP   7m43s
```

In this above example, I have keycloak (IdP) and ldap with an external IP of `172.69.1.2` and `172.69.1.1` respectively. While I can directly access this via the IP, we can also map a hostname for easier access, by adding a record to our `/etc/hosts` file

```
172.69.1.2 keycloak.confluentdemo.io
172.69.1.1 ldap.confluentdemo.io
```

When we deploy a CR that has `externalAccess` configuration such as for Kafka and Control Center.

```
# Kafka
spec:
  listeners:
    external:
      ..........
      externalAccess:
        type: loadBalancer
        loadBalancer:
          domain: confluentdemo.io
          brokerPrefix: "kafkabroker-"
```

or

```
# Control Center
spec:
  externalAccess:
    type: loadBalancer
    loadBalancer:
      domain: confluentdemo.io
      port: 443
```

This will result in the following

```
kubectl -n confluent get svc
NAME                         TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                                                                                     AGE
confluent-operator           ClusterIP      10.43.47.228    <none>        7778/TCP                                                                                    11m
controlcenter                ClusterIP      None            <none>        9021/TCP,7203/TCP,7777/TCP,7778/TCP,9090/TCP,9093/TCP                                       8m7s
controlcenter-0-internal     ClusterIP      10.43.119.237   <none>        9021/TCP,7203/TCP,7777/TCP,7778/TCP,9090/TCP,9093/TCP                                       8m7s
controlcenter-bootstrap-lb   LoadBalancer   10.43.3.184     172.69.1.7    443:30250/TCP                                                                               8m7s
kafkabroker                  ClusterIP      None            <none>        9074/TCP,9092/TCP,8090/TCP,9071/TCP,7203/TCP,7777/TCP,7778/TCP,9072/TCP,9073/TCP,9075/TCP   9m24s
kafkabroker-0-internal       ClusterIP      10.43.14.26     <none>        9074/TCP,9092/TCP,8090/TCP,9071/TCP,7203/TCP,7777/TCP,7778/TCP,9072/TCP,9073/TCP,9075/TCP   9m24s
kafkabroker-0-lb             LoadBalancer   10.43.25.32     172.69.1.3    9092:30714/TCP                                                                              9m24s
kafkabroker-1-internal       ClusterIP      10.43.93.178    <none>        9074/TCP,9092/TCP,8090/TCP,9071/TCP,7203/TCP,7777/TCP,7778/TCP,9072/TCP,9073/TCP,9075/TCP   9m24s
kafkabroker-1-lb             LoadBalancer   10.43.140.185   172.69.1.4    9092:32478/TCP                                                                              9m24s
kafkabroker-2-internal       ClusterIP      10.43.148.212   <none>        9074/TCP,9092/TCP,8090/TCP,9071/TCP,7203/TCP,7777/TCP,7778/TCP,9072/TCP,9073/TCP,9075/TCP   9m24s
kafkabroker-2-lb             LoadBalancer   10.43.244.93    172.69.1.5    9092:32541/TCP                                                                              9m24s
kafkabroker-bootstrap-lb     LoadBalancer   10.43.126.164   172.69.1.6    9092:32435/TCP                                                                              9m24s
kafkacontroller              ClusterIP      None            <none>        9074/TCP,7203/TCP,7777/TCP,7778/TCP,9072/TCP                                                10m
kafkacontroller-0-internal   ClusterIP      10.43.5.178     <none>        9074/TCP,7203/TCP,7777/TCP,7778/TCP,9072/TCP                                                10m
kafkacontroller-1-internal   ClusterIP      10.43.242.90    <none>        9074/TCP,7203/TCP,7777/TCP,7778/TCP,9072/TCP                                                10m
kafkacontroller-2-internal   ClusterIP      10.43.198.215   <none>        9074/TCP,7203/TCP,7777/TCP,7778/TCP,9072/TCP                                                10m
```

So now we have external IPs that we can use to access those components from our host machine.

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
