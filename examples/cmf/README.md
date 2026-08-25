# CMF

This is an example of a CP and CMF setup, you can use this to test CMF using Kakfa MDS as opposed to Embedded MDS.

Here we are specifically using CFK 3.1.0 and CP 8.0.6

## Start

1. Start kube-playground with Keycloak, LDAP, and Flink Operator. We will deploy CMF manually later.

```
cd kube-playground
export BASE_DIR=$(pwd)
./start.sh -v 3.1.0 -e idp,ldap,flink
```

2. Deploy Kubernertes Secrets

```
cd examples/cmf
./setup.sh
```

3. Deploy Kraft Controllers and Kafka Brokers

```
kubectl apply -f confluent-platform-base.yaml
```

4. Deploy KafkaRestClass

Here you can choose to deploy a KRC that uses Bearer authentication against MDS or OAUTH authentication.

```
kubectl apply -f kafkarestclass-bearer.yaml
# or
kubectl apply -f kafkarestclass-oauth.yaml
```

5. Deploy CMF

a. Deploy Embedded MDS in CMF
This option allows for a CMF deploy that does not require CP Kafka/MDS, Rolebindings need to be configured manually.

```
# SSO Authentication with OAUTH Userstore
./scripts/helper/deploy-cmf.sh -v 2.4.1 -n confluent -m -z -u oauth -a sso

# Basic Authentication with LDAP Userstore
./scripts/helper/deploy-cmf.sh -v 2.4.1 -n confluent -m -z -u ldap -a basic

# Basic Authentication with FILE Userstore
./scripts/helper/deploy-cmf.sh -v 2.4.1 -n confluent -m -z -u file -a basic

# LDAP and OAUTH Userstore, allows for SSO or Basic Auth
./scripts/helper/deploy-cmf.sh -v 2.4.1 -n confluent -m -z -u ldap_with_oauth
```

b. Deploy Remote MDS in CMF (e.g. CP-MDS)
This option allows for CP to provide MDS, allowing for Rolebindings to be configured in CP.

First we need to configure Rolebindings before the CMF deployment

```
kubectl apply -f rolebindings.yaml
```

Then we can deploy CMF.

```
# SSO Authentication
./scripts/helper/deploy-cmf.sh -v 2.4.1 -n confluent -r -a sso

# Basic Authentication (LDAP)
./scripts/helper/deploy-cmf.sh -v 2.4.1 -n confluent -r -a basic
```

6. Adding Host Records for ExternalAccess

```
../../../scripts/helper/add-hosts-records.sh
```

8. Access CMF UI

You can now access CMF in the UI at

```
https://cmf.confluentdemo.io
```

Depending on how you deployed CMF, you can either login via the SSO method using

```
username: donnatroy@confluentdemo.io
password: donnatroy-secret
```

Or login using username and password

```
username: donnatroy
password: donnatroy-secret
```

9. Deploy CMFRestClass
   You can further configure the CMFRestClass with mTLS authentication so that CFK Operator can interact with CMF.

```
kubectl apply -f cmfrestclass.yaml
```
