# kube-playground

Quickly and easily create local kubernetes resources and external assets to aid in the deployment and testing of CFK.

The goal here is to be able to develop/test your own CRs local with pre-built opinionated assets that can offer seamless re-deployment to new clusters.

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

## TODO

- [x] Create initial k3d deployment helper
- [x] Create automated openldap deployment
- [x] Create automated keycloak deployment
- [x] Create automated CFK deployment
- [x] Add auto generated ssl helper scripts
- [x] Add auto generated credential helper scripts
- [x] Add workflow for using multipass vm for k3d instead of local k3d deployment
- [ ] Add workflow for Openshift connection
- [ ] ~~Create CR Generator~~
- [ ] Add Terraform workflow
  - [ ] AWS (EKS)
  - [ ] ~~AWS (ROSA) needs subscription~~
  - [ ] Azure (AKS)
  - [ ] Azure (Openshift)
- [ ] Add REST helper scripts (get Bearer Token)
- [x] Add Flink Deployment
- [ ] ~~Add USM deployment~~
- [ ] Add setup for Confluent Private Cloud Gateway
- [x] Add FIPs asset generation
- [x] Added File Based Userstore creation
- [x] Add oidcClientSecret.txt deployment
- [x] Add helper script for externalAccess
- [x] Add helper script for preseeding images

## Default Kubernetes Cluster

The default behavior is to spin up a Kubernetes cluster using k3d, this must be installed ahead of time.
Alternatie approach is to use multipass and spin up k3d within the multipass VM.

### Option 1: Install k3d

This assumes you already have k3d installed.
Follow the installation instruction on [k3d.io](https://k3d.io)

For Mac (Using Homebrew)

```
brew install k3d
```

### Option 2: Using Multipass VM

Start with passing `multipass` argument

```
./start.sh -m multipass -v 2.11.0
```

### Option 3: Openshift Local

Deploy to Openshift Local, this requires CRC installed ahead of time. Follow instructions from [RedHat](https://console.redhat.com/openshift/create/local)

```
CRC_PULL_SECRET=/Users/<username>/.crc/pull-secret.txt ./start.sh -m openshift -v 2.11.0
# if omitted, it will try to check $HOME/.crc/pull-secret.txt
./start.sh -m openshift -v 2.11.0
```

### Option 4: No Infrastructure

Don't deploy any infrastructure, this can be useful if you have an external Kubernetes Cluster

```
./start.sh -s -v 2.11.0
```

## Install the docker-mac-net-connect

This is used to provide a networking path to docker containers in MacOS by creating a `utun` network interface and then adds a route automatically.

```
sudo brew install chipmk/tap/docker-mac-net-connect
```

Start|Stop|Restart

```
sudo brew services start|stop|restart chipmk/tap/docker-mac-net-connect
```

### Issue with newer Docker Desktop Versions

There's an issue I encountered with newer versions of Docker Desktop as noted in this [Github Issue](https://github.com/chipmk/docker-mac-net-connect/issues/62) so it'd be best to start docker-mac-net-connect with

```
sudo env DOCKER_API_VERSION=1.44 docker-mac-net-connect
```

## Adding records to /etc/hosts for externalAccess

We can deploy CRs with `externalAccess` configuration and be able to access them from your host machine by mapping a hostname to the IPs assigned by MetalLB.
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

## add-hosts-records.sh

I've added this helper script which will configure our `/etc/hosts` file for us based on services that it finds an external IP for. Please note it does require sudo privileges for some of the steps as it involves modifying a privilege file.

```
./scripts/helper/add-hosts-records.sh
```

This will make a backup copy of our `/etc/hosts` file with a timestamp before actual modification.

When ran it will look like

```
........
There are custom records found!
Clearing custom records with based domain: confluentdemo.io...

Backing up /etc/hosts ...
/etc/hosts is now cleared of custom records!
Adding record for keycloak.confluentdemo.io
Adding record for ldap.confluentdemo.io
Adding record for controlcenter.confluentdemo.io
Adding record for kafkabroker-0.confluentdemo.io
Adding record for kafkabroker-1.confluentdemo.io
Adding record for kafkabroker-2.confluentdemo.io
Adding record for kafkabroker.confluentdemo.io
```

and our `/etc/hosts` will have the following entries appended at the bottom.

```
# keycloak.confluentdemo.io Added by kube-playground
172.69.1.2 keycloak.confluentdemo.io
# ldap.confluentdemo.io Added by kube-playground
172.69.1.1 ldap.confluentdemo.io
# controlcenter.confluentdemo.io Added by kube-playground
172.69.1.7 controlcenter.confluentdemo.io
# kafkabroker-0.confluentdemo.io Added by kube-playground
172.69.1.3 kafkabroker-0.confluentdemo.io
# kafkabroker-1.confluentdemo.io Added by kube-playground
172.69.1.4 kafkabroker-1.confluentdemo.io
# kafkabroker-2.confluentdemo.io Added by kube-playground
172.69.1.5 kafkabroker-2.confluentdemo.io
# kafkabroker.confluentdemo.io Added by kube-playground
172.69.1.6 kafkabroker.confluentdemo.io
```

So with this we can now navigate to `https://controlcenter.confluentdemo.io` in our web browser and be able to access Control Center without having to go the `port-forward` route with a local kubernetes cluster.

## Prerequisites

Make sure you make a copy of the `.env.example` file and configure it for defaults

```
cp .env.example .env
```

## Usage

You can deploy base k3d environment using the following command

```
export BASE_DIR=$(pwd)
./start.sh
```

You can automate deployment of LDAP or IDP

You can also automate CFK deployment by providing either the CFK Helm version or CFK Operator Image Version.
NOTE\* These versions are checked against a local mapping that's in `./configs/cfk/version_mapping.json` which is periodically updated.

```
export BASE_DIR=$(pwd)
./start.sh -v 2.11.1
```

or

```
export BASE_DIR=$(pwd)
./start.sh -v 0.1193.34
```

### Generate SSL files and scripts

You can automate the creation of SSL files (PEM and jks), this is opinionated and will generate SSL certificates for the following components

```
connect
controlcenter
kafkabroker
kafkarestproxy
keycloak
kraftcontroller
ksqldb
openldap
replicator
schemaregistry
zookeeper
```

This will also generate shell scripts which you can then use to create kubernetes secret. These will be found in `generated/ssl/cmd`

You can then just run the shell script to create said secret

```
cat generated/ssl/cmd/kraftcontroller/create-tls-kraftcontroller-secret.sh
#!/bin/sh
kubectl -n confluent create secret generic tls-kraftcontroller --from-file=fullchain.pem=/Users/huy.nguyen/projects/github/kube-playground/generated/ssl/component/certs/kraftcontroller-fullchain.pem --from-file=cacerts.pem=/Users/huy.nguyen/projects/github/kube-playground/generated/ssl/intermediate_ca/certs/fullchain.pem --from-file=privkey.pem=/Users/huy.nguyen/projects/github/kube-playground/generated/ssl/component/private/kraftcontroller.key
```

As you can see the `kubectl` command is autogenerated based on predetermined paths and namespace set by the `.env` file. When executed it should be successful.

> [!WARNING]
> Please always review shell scripts before executing!

```
source generated/ssl/cmd/kraftcontroller/create-tls-kraftcontroller-secret.sh
secret/tls-kraftcontroller created
```

This will allow you to re-create the kubernetes secret on new cluster deployment without having to re-generate ssl files, so long as they exist.

## Run CFK Version Extractor

While kube-playground stores a manual copy of CFK Version to Image Tag mapping, it may not always be up to date. You can use the following script to manually generate a new mapping combining default mapping with what we pull from [Confluent Documentation](https://docs.confluent.io/operator/current/co-plan.html#co-long-image-tags) thus creating a brand new mapping.

```
export BASE_DIR=$(pwd)
./scripts/helper/cfk-version-extractor.sh
```

If the version differs, it would be advised to replace the old mapping at `$BASE_DIR/configs/cfk/version_mapping.json` with the new file from `$BASE_DIR/generated/cfk/version_mapping.json` until kube-playground is updated with this new copy.

## Deploy LDAP

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

## Deploy IDP

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
