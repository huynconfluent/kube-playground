# Openshift

This is an example of deploying CP to Openshift via kube-playground.

> [!NOTE]
> Please note that since Openshift CRC is a single node cluster, this example is heavily downsized to be single component deployments.

> [!NOTE]
> Make sure you've already gone through the additional setup/install for Openshift CRC as that's needed here.

## Start

```
cd kube-playground
export BASE_DIR=$(pwd)
./start.sh -m openshift -v 3.1.1 -e idp
```

## Using the pre-seed Script

Since our goal is to deploy CP 8.0.0 (ubi9) images and Control Center Next Gen 2.2.0 (ubi9), we'll need to pre-seed the container images. This can be done before Openshift deployment or after.

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/helper/pre-seed.sh -o 3.1.1 -c 8.0.0 -m 2.2.0 -t ubi9.arm64
```

> [!NOTE]
> Follow the prompts and select the components we wish to download
> cp-server, cp-schema-registry, cp-server-connect, cp-kafka-rest

## Using the push-to-crc-registry Script

Once we have Openshift deployed, we can follow up and push our ubi9 images to our Openshift Container Registry. Without doing this, the time it'll take for Openshift to manually download the same CP Container Images can result in a very long deployment time.

```
cd kube-playground
export BASE_DIR=$(pwd)
./script/helper/push-to-crc-registry.sh -o 3.1.1 -c 8.0.0 -m 2.2.0 -t ubi9.arm64
```

## Deploy Secrets

```
cd kube-playground
export BASE_DIR=$(pwd)
cd examples/openshift
./setup.sh
```

## Deploy Confluent Platform Base (Kafka Controller and Kafka Broker)

```
oc apply -f confluent-platform-base.yaml
```

## Deploy Components and C3

```
oc apply -f confluent-platform-components.yaml
oc apply -f confluent-platform-c3.yaml
```

## Run Add Host Records

Run the helper script to add host Route Host Records to your local `/etc/hosts` file.

> [!NOTE]
> This requires escalated privileges, so you will be prompted for your password.
> Alternatively you can see what changes will be made by using the `-d` flag with the command.

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/helper/add-hosts-records.sh
```

When you cat this out you should see an entry at the bottom that looks like

```
# keycloak.confluentdemo.io controlcenter.confluentdemo.io kafkabroker-0.confluentdemo.io kafkabroker.confluentdemo.io Added by kube-playground
127.0.0.1 keycloak.confluentdemo.io controlcenter.confluentdemo.io kafkabroker-0.confluentdemo.io kafkabroker.confluentdemo.io
```

## Accessing Control Center

You can now access Control Center in the UI at

```
https://controlcenter.confluentdemo.io/
```

You can login using one of the SSO users

```
username: sambridges@confluentdemo.io
password: sambridges-secret
```

## Apply rolebindings

Because our user doesn't have any Rolebindings we cannot access the Kafka Cluster. So let's add Rolebindings

```
oc apply -f rolebindings.yaml
```

Then check control center again
