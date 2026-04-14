# Openshift Local

# Getting Started

The Openshift Local deployment uses RedHat's CRC tool to create a VM to run a single node Openshift Cluster.
Kube-playground cannot work without the initial Manual setup.

## Install CRC

You'll need to have a RedHat account to download the CRC CLI tool as well as obtain a `pull-secret.txt` from RedHat to use the CRC VM.

[link](https://console.redhat.com/openshift/create/local)

Installing CRC will generate a local cache directory where the CRC VM images are stored

```
~/.crc
```

I would also recommend storing your `pull-secret.txt` here as well to make it easy to remember.

## Deploying Openshift Local

I'm making some assumptions here with regards to the resources for the CRC VM. Please see the `.env.example` for what those assumptions are

```
CRC_PULL_SECRET_FILE="$HOME/.crc/pull-secret.txt"
CRC_CPU_CORES="8"
CRC_MEMORY_MB="16384"
CRC_DISK_SIZE_GB="150"
```

Basically the CRC VM will be created with 8 CPU Cores, 16GB of RAM and 150GB of storage.

### Versioning

Generally the CRC Version is the Openshift Version.

```
crc version
WARN A new version (2.60.1) has been published on https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/crc/2.60.1/crc-macos-installer.pkg
CRC version: 2.59.0+e90757
OpenShift version: 4.21.4
MicroShift version: 4.21.0
```

However you can use kube-playground to deploy a different Openshift Version.

### Default Deployment

```
./start.sh -m openshift
```

The above command will assume the following

- Your `pull-secret.txt` is located in `$HOME/.crc/pull-secret.txt`
- You will deploy Latest version of CFK
- You will create an single node Openshift cluster matching the version of your CRC installed.

### Deploy a Specific version of Openshift

```
CRC_OPENSHIFT_VERSION=4.18.2 ./start.sh -m openshift
```

The above command will do the same as the previous, but this time we're specifying our Openshift Version. Kube-playground will attempt to download that CRCVM version into the cache if it doesn't exist. This can be time consuming.

## Downloading Other CRCVM versions

You can use the helper script `get-crc-bundle.sh` to download a specific version into your crc cache.

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/helper/get-crc-bundle.sh -v 4.21 -p openshift
```

This will attempt to download the 4.21 openshift version into your `$HOME/.crc/cache` directory.
This script is also called by the `deploy-openshift-local.sh` script when it's ran.

## Copy Container Images to Openshift Container Registry

You can download and push container imaes to/from your local Docker Registry to the Openshift Container Registry. This will greatly speed up pod deployments in local kubernetes.

### Pre-seed Container Images

You can use the `pre-seed.sh` helper script to download container images.

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/helper/pre-seed.sh
```

I made this using `gum` to provide an interactive menu, but you can also use option flags.

```
./scripts/helper/pre-seed.sh -o 3.1.1 -c 8.0.0 -m 2.2.0
```

The script will check against your docker pull rate limit and will attempt to download from docker hub.

You can also use the `-d` flag for a dry run without actually pulling anything.

```
./scripts/helper/pre-seed.sh -d
```

This script will prompt you to run the Push to CRC script after pre-seeding.

### Push to CRC VM

Alternatively you can also just run the `push-to-crc-registry.sh` manually as well providing the options flags. This it not interactive.
This helper script, effectively tags your local images and then pushes it to the CRC VM's registry, this assumes that it will be added to the `confluent` namespace/project in Openshift.

```
./scripts/helper/push-to-crc-registry.sh -o 3.1.1 -c 8.0.0 -m 2.2.0 -t -1-ubi9.arm64
```

You can also do a dry run of this as well

```
./scripts/helper/push-to-crc-registry.sh -o 3.1.1 -c 8.0.0 -m 2.2.0 -t -1-ubi9.arm64 -d
```

## Using local images in Openshift

After you have push the local images, you can modify your CR YAML files to reference this local image by replacing the typical `confluentinc/` portion with `default-route-openshift-image-registry.apps-crc.testing/confluent`

```
spec:
  .......
  image:
    application: default-route-openshift-image-registry.apps-crc.testing/confluent/cp-server:8.0.0-1-ubi9.arm64
    init: default-route-openshift-image-registry.apps-crc.testing/confluent/confluent-init-container:3.1.1.arm64
```

## Stopping Openshift

You can use the `stop.sh` script to shutdown the CRC. Starting it next time via `start.sh` will resume the VM. You can also delete the VM to start fresh for next time.

```
./stop.sh -d
```
