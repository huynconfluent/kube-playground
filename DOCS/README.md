# DOCUMENTATION

# Getting Started

This assumes you have installed all prerequisite programs needed to run kube-playground.

## Creating a .env

You'll want to make a copy of the `.env.example` file

```
cd kube-playground
cp .env.example .env
```

Feel free to modify this file as this makes a lot of base assumptions. For example we will assume that the Namespace we will deploy CFK into will be `CFK_NAMESPACE=confluent` which is set by this file.

## Create k3d infrastructure and deploy CFK

The most bare bones setup will deploy Confluent for Kubernetes using the latest Helm version.

```
cd kube-playground
export BASE_DIR=$(pwd)
./start.sh
```

This will create the Kubernetes infrastructure using k3d and it will deploy CFK using latest Helm Version into the `CFK_NAMESPACE`

Please note it is extremely important that we set `BASE_DIR` as the base directory for `kube-playground` This ensure the scripts knows where to find files.

## Deploy specific CFK version

You can deploy a specific CFK Version using a few different methods.

### Method 1: Deploy CFK Helm Version

```
./start.sh -v 3.1.1
```

### Method 2: Deploy CFK Operator Version

```
./start -v 0.1351.59
```

### Method 3: Deploy CFK after you've already deployed Kubernetes Infrastructure

```
./scripts/helper/deploy-cfk.sh -v 3.1.1
# or
./scripts/helper/deploy-cfk.sh -v 0.1351.59
```

## Tearing Down kube-playground

Stopping is easy

```
cd kube-playground
export BASE_DIR=$(pwd)
./stop.sh
```

If you are stopping a VM (such as multipass or Openshift Local) and want to destroy the resource use the `-d` flag

```
./stop.sh -d
```
