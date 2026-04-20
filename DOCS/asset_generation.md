# Asset Generation

> [!WARNING]
> Please always review shell scripts before executing!

Kube-playground is opinionated in it's asset generation. It assumes a predefined set of users, credentials and certificates in order to be interchangeable between different authentication methods.
This allows for flexiblity when testing one authentication (e.g. SASL/PLAIN) and moving to another authentication (e.g. SASL/PLAIN with LDAP Callback + MDS)

The goal of Asset Generation in kube-playground is to have a consistent, interchangeable file assets that is used in combination with pre-generated helper scripts to speed up secret deployments to kubernetes. Kube-playground will generate the following assets and thier helper scripts

So the benefit of this is that you have physical assets that you can use in any deployment and to speed up secret creation without having to memorize or even copy/paste commands.

Kube-playground will generate the following assets

- PEM files (Self Signed CA, Intermediate CA, and Server/Client Certificates)
- P12, JKS, and BCFKS Keystores/Truststores
- MDS Keypair files (Public and Private Keys)
- LDAP MDS Bind User Credential
- Basic Auth Credentials
- Bearer Auth Credentials
- OAUTH Credentials (Both oauth-jaas.conf and oauth.txt)
- OIDC Credential (oidcClientSecret.txt used for SSO setup)
- SASL/DIGEST Credentials
- SASL/PLAIN Credentials
- File Based Userstore (to be used with MDS with backing File Userstore)

## Credentials

All credentials follows a predefined format.

```
Username: <username>
Password: <username>-secret
```

> [!NOTE]
> Where this differ is with SSO authentication, that follows a different format for User login.
> Username: `<firstname>@confluentdemo.io`
> Password: `<firstname>-secret`

## Autogenerate Assets on Start

You can use the `-a` option flag to autogenerate assets into the `$BASE_DIR/generated` directory on start. It will skip this autogenerate if it detects items already existing.

```
cd kube-playground
export BASE_DIR=$(pwd)
./start.sh -a
```

The above will deploy a `k3d` cluster, auto deploy CFK Operator using the latest Helm Version and will generate TLS assets, CFK specific credential assets.

## Autogenerate Assets without Start

The `start.sh` script will call the following helper script to autogenerate the assets

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/helper/deploy-ssl.sh
./scripts/helper/deploy-creds.sh
```

What's great about this is that these scripts can take an optional flag for a clean deployment (e.g. delete and re-create)

### Delete and Re-create Assets

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/helper/deploy-ssl.sh -c
./scripts/helper/deploy-creds.sh -c
```

> [!CAUTION]
> This will delete the contents of `$BASE_DIR/generated/ssl` and `$BASE_DIR/generated/creds`
> So be careful when using this optional flag.

## Generate SASL/OAUTH Assets

You can manually generate SASL/OAUTH assets by providing a json file of credentials and a namespace where we will create assets in.

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/creds/create-sasl-oauth.sh -n <namespace> -u <user_json_file>
```

This will generate the following directories and files in `$BASE_DIR/oauth`

```
cmd/
cmd/create-sasl-oauth-jaas-<username>-secret.sh
cmd/create-sasl-oauth-txt-<username>-secret.sh
files/
files/jaas/
files/jaas/<username>-oauth-jaas.conf
files/txt/
files/txt/<username>-oauth.txt
```

### Example of jaas file

When provided a MDS Public Key along with Truststore information, the following is what the `jaas.conf` will look like. This can then be used within a Confluent Platform pod (e.g. kafka broker) and will be able to authenticate to a SASL/OAUTHBEARER listener that uses OAUTH 2.0.

```
sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required \
        clientId="kafkabroker" \
        clientSecret="kafkabroker-secret" \
        unsecuredLoginStringClaim_sub="kafkabroker" \
        publicKeyPath="/mnt/sslcerts/keypair/mds-keypair-public.pem" \
        ssl.truststore.location="/mnt/sslcerts/truststore.p12" \
        ssl.truststore.password="mystorepassword";
```

### Example of txt file

The txt files are barebones and only include a `clientId` and `clientSecret` which are used for OAUTH 2.0

```
clientId=kafkabroker
clientSecret=kafkabroker-secret
```

### Executing the shell script

With assets, this will also autogenerate a shell script to quickly create the asset in kubernetes.

This means that you can execute the following shell scripts and it will create a kubernetes secret in the pre-defined namespace when you created the asset the following shell script and it will create a kubernetes secret in the pre-defined namespace when you created the asset.

#### Creating OAUTH jaas.conf Secret

```
./create-sasl-oauth-jaas-kafkabroker-secret.sh
secret/ojaas-kafkabroker created
```

#### Creating OAUTH .txt Secret

```
./create-sasl-oauth-txt-kafkabroker-secret.sh
secret/otxt-kafkabroker created
```

### Example of the shell script

Let's take a look at the contents of the shell script. This shows us that the shell script will attempt to execute using `kubectl` by default and using the defined namespace here `confluent` by default.

```
#!/bin/sh

# ./create-sasl-oauth-jaas-kafkabroker-secret.sh [kubectl|oc] [namespace]

KCMD=${1:-kubectl}
NAMESPACE=${2:-confluent}
eval "$KCMD -n $NAMESPACE create secret generic ojaas-kafkabroker --from-file=oauth-jaas.conf=/PATH/TO/kube-playground/generated/creds/oauth/files/jaas/kafkabroker-oauth-jaas.conf"
```

However this also means that we can provide some additional arguments in order to alter our deployment. We can still provide `kubectl` as our choice for cli too, but we can then provide a different namespace too.

```
./create-sasl-oauth-jaas-kafkabroker-secret.sh kubectl default
```

This will allow these helpers script to be extremely flexible to your desired deployment testing.

### Creating a JSON file

The creation helper script takes in a JSON file that consist of username+password key pairs.

```
{
    "username1": "password",
    "username2": "password"
}
```

## Generate SASL/PLAIN Assets

You can manually generate SASL/PLAIN assets by providing a json file of credentials, interbroker credentials and a namespace where we will create assets in.

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/creds/create-sasl-plain-auth.sh -n <namespace> -u <user_json_file> -i <interbroker_username>:<interbroker_user_password>
```

This will generate the following directories and files in `$BASE_DIR/sasl-plain`

```
cmd/
cmd/create-client-sasl-plain-jaas-<username>-secret.sh
cmd/create-client-sasl-plain-txt-<username>-secret.sh
cmd/create-server-sasl-plain-json-secret.sh
cmd/create-server-sasl-plain-jaas-secret.sh
client-side/
client-side/<username>-plain-jaas.conf
client-side/<username>-plain.txt
server-side/
server-side/plain-interbroker.txt
server-side/plain-jaas.conf
server-side/plain-users.json
```

### Example of client side jaas file

The client side `plain-jaas.conf` contains just the username and password.

```
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
        username="kafkabroker" \
        password="kafkabroker-secret";
```

### Example of client side txt file

The client side `plain.txt` contains just the username and password.

```
username=kafkabroker
password=kafkabroker-secret
```

### Example of server side txt file

This is the `plain-interbroker.txt` credential that's used to authenticate to another broker's inter broker listener using SASL/PLAIN authentication. This is just username and password.

```
username=kafkabroker
password=kafkabroker-secret
```

### Example of server side jaas file

The is the `plain-jaas.conf` that's used with a SASL/PLAIN Kafka Listener, it contains both the client's authentication AND the database of credentials that would be check should a client authenticate against it.

```
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
        username="kafkabroker" \
        password="kafkabroker-secret" \
        user_zookeeper="zookeeper-secret" \
        user_kafkabroker="kafkabroker-secret" \
        .......;
```

### Example of server side json file

This is the `plain-users.json` file that CFK can use to define a SASL/PLAIN Kafka Listener. This is already pre-generated, we just copy it from `$BASE_DIR/configs/creds/default-plain-users.json` into the generated directory.

```
{
    "<username>": "<username>-secret",
    .........
}
```

### Executing the shell script

With assets, this will also autogenerate a shell script to quickly create the asset in kubernetes.

This means that you can execute the following shell scripts and it will create a kubernetes secret in the pre-defined namespace when you created the asset the following shell script and it will create a kubernetes secret in the pre-defined namespace when you created the asset.

#### Creating client side SASL/PLAIN plain-jaas.conf Secret

```
./create-client-sasl-plain-jaas-kafkabroker-secret.sh
secret/pjaas-kafkabroker created
```

#### Creating client side SASL/PLAIN plain.txt Secret

```
./create-client-sasl-plain-txt-kafkabroker-secret.sh
secret/ptxt-kafkabroker created
```

#### Create server side SASL/PLAIN plain-users.json Secret

This is used with `jaasConfig`

```
./create-server-sasl-plain-json-secret.sh
secret/server-sasl-plain-json
```

#### Create server side SASL/PLAIN plain-jaas.conf Secret

This is used with `jaasConfigPassthrough`

```
./create-server-sasl-plain-jaas-secret.sh
secret/server-sasl-plain-jaas
```

## Generate SASL/DIGEST Assets

You can manually generate SASL/DIGEST assets by providing a json file of credentials and a namespace where we will create assets in.

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/creds/create-sasl-digest-auth.sh -n <namespace> -u <user_json_file>
```

This will generate the following directories and files in `$BASE_DIR/sasl-digest`

```
cmd/
cmd/create-client-digest-jaas-kafkabroker-secret.sh
cmd/create-client-digest-jaas-zookeeper-secret.sh
cmd/create-client-digest-txt-kafkabroker-secret.sh
cmd/create-client-digest-txt-zookeeper-secret.sh
cmd/create-server-digest-json-zookeeper-secret.sh
cmd/create-server-digest-jaas-zookeeper-secret.sh
client-side/
client-side/kafkabroker-digest.txt
client-side/kafkabroker-jaas.conf
client-side/zookeeper-digest.txt
client-side/zookeeper-jaas.conf
server-side/
server-side/digest-jaas.conf
server-side/digest-users.json
```

### Example of client side jaas file

The client side `digest-jaas.conf` contains just the username and password.

```
Client {
        org.apache.zookeeper.server.auth.DigestLoginModule required
        username="kafkabroker"
        password="kafkabroker-secret";
};
```

### Example of client side txt file

```
username=kafkabroker
password=kafkabroker-secret
```

### Example of server side jaas file

```
Server {
        org.apache.zookeeper.server.auth.DigestLoginModule required
        user_zookeeper="zookeeper-secret"
        user_kafkabroker="kafkabroker-secret";
};

QuorumServer {
        org.apache.zookeeper.server.auth.DigestLoginModule required
        user_zookeeper="zookeeper-secret";
};

QuorumLearner {
        org.apache.zookeeper.server.auth.DigestLoginModule required
        user="zookeeper"
        password="zookeeper-secret";
};
```

### Example of server side json file

By default kube-playground copies a predefine json file from `$BASE_DIR/configs/creds/default-digest-users.json` into the generated directory.

```
{
  "zookeeper": "zookeeper-secret",
  "kafkabroker": "kafkabroker-secret"
}
```

### Executing the shell script

With assets, this will also autogenerate a shell script to quickly create the asset in kubernetes.

This means that you can execute the following shell scripts and it will create a kubernetes secret in the pre-defined namespace when you created the asset the following shell script and it will create a kubernetes secret in the pre-defined namespace when you created the asset.

#### Creating client side SASL/DIGEST digest-jaas.conf Secret

```
./create-client-digest-jaas-kafkabroker-secret.sh
secret/djaas-kafkabroker created
```

#### Creating client side SASL/DIGEST digest.txt Secret

```
./create-client-digest-txt-kafkabroker-secret.sh
secret/dtxt-kafkabroker created
```

#### Create server side SASL/DIGEST digest-jaas.conf Secret

```
./create-server-digest-jaas-zookeeper-secret.sh
secret/digest-zookeeper-server-jaas
```

#### Create server side SASL/DIGEST digest-users.json Secret

```
./create-server-digest-json-zookeeper-secret.sh
secret/digest-zookeeper-server-json
```

## Generate BASIC Auth Assets

You can manually generate Basic Auth assets by providing the component, an array of credentials and a namespace.

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/creds/create-basic-auth.sh -n <namespace> -p <restproxy|ksqldb|schemaregistry|connect|controlcenter|prometheus> -u "username1:password:role,username2:password:role"
```

This will generate the following directories and files in `$BASE_DIR/sasl-digest`

```
cmd/
cmd/create-basic-client-<component>-secret.sh
cmd/create-basic-server-<component>-secret.sh
client-side/
client-side/<component>/
client-side/<component>/<username>-basic.txt
server-side/
server-side/<component>/
server-side/<component>/basic.txt
```

### Example of client side baisc.txt file

```
username=<username>
password=<username>-secret
```

### Example of server side basic.txt file

For components without roles

```
<username>:<username>-secret
```

For components with roles

```
<username1>: <username1>secret,<role>
<username2>: <username2>secret,<role>
```

### Executing the shell script

With assets, this will also autogenerate a shell script to quickly create the asset in kubernetes.

This means that you can execute the following shell scripts and it will create a kubernetes secret in the pre-defined namespace when you created the asset the following shell script and it will create a kubernetes secret in the pre-defined namespace when you created the asset.

#### Creating client side basic auth Secret

```
./create-client-basic-<username>-secret.sh
secret/cbasic-<username>
```

#### Creating server side basic auth Secret

```
./create-server-basic-<username>-secret.sh
secret/sbasic-<username>
```

## Generate File Based User Store Assets

You can manually generate a File Based userstore.txt providing a namespace, encryption type and credential file

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/creds/create-file-userstore.sh -n <namespace> -e none -u /path/to/userstore.txt
```

```
cmd/
cmd/create-cleartext-userstore-secret.sh
files/
files/cleartext-userstore.txt
```

### Creating a credential file

The creation helper script takes in a credentials file containing username:passwords. The auto generated asset uses a predefined userstore from `$BASE_DIR/configs/creds/default-userstore.txt`

```
username1:username1-secret
username2:username2-secret
```

### Executing the shell script

With assets, this will also autogenerate a shell script to quickly create the asset in kubernetes.

This means that you can execute the following shell scripts and it will create a kubernetes secret in the pre-defined namespace when you created the asset the following shell script and it will create a kubernetes secret in the pre-defined namespace when you created the asset.

#### Creating userstore Secret

```
./create-cleartext-userstore-secret.sh
secret/cleartext-userstore
```

## Generate MDS LDAP Bind User Asset

You can manually generate MDS LDAP bind user asset by providing a namespace, bind user credentials.

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/creds/create-mds-binduser.sh -n <namespace> -u "cn=admin,dc=confluentdemo,dc=io" -p "ldapadmin-topsecret\!"
```

```
cmd/
cmd/create-mds-binduser-secret.sh
files/
files/ldap.txt
```

### Executing the shell script

With assets, this will also autogenerate a shell script to quickly create the asset in kubernetes.

This means that you can execute the following shell scripts and it will create a kubernetes secret in the pre-defined namespace when you created the asset the following shell script and it will create a kubernetes secret in the pre-defined namespace when you created the asset.

#### Creating MDS ldap.txt Secret

```
./create-mds-binduser-secret.sh
secret/mds-binduser
```

## Generate Bearer Auth Assets

You can manually generate bearer credentials by providing a namespace and a credential json file.

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/creds/create-bearer-auth.sh -n <namespace> -u /path/to/user.json
```

```
cmd/
cmd/create-bearer-<username>-secret.sh
files/
files/<username>-bearer.txt
```

### Creating a JSON file

The creation helper script takes in a JSON file that consist of username+password key pairs.

```
{
    "username1": "password",
    "username2": "password"
}
```

### Executing the shell script

With assets, this will also autogenerate a shell script to quickly create the asset in kubernetes.

This means that you can execute the following shell scripts and it will create a kubernetes secret in the pre-defined namespace when you created the asset the following shell script and it will create a kubernetes secret in the pre-defined namespace when you created the asset.

#### Creating bearer.txt Secret

```
./create-bearer-<username>-secret.sh
secret/bearer-<username>
```

## Generate OIDC Credential Secret

You can manually generate a OIDC Credential Secret used for SSO configuration by providing a namespace and credentials.

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/creds/create-oidc-client-auth.sh -n <namespace> -u <clientId> -p <clientSecret>
```

```
cmd/
cmd/create-oidc-<clientId>-secret.sh
files/
files/<clientId>-oidcClientSecret.txt
```

### Executing the shell script

With assets, this will also autogenerate a shell script to quickly create the asset in kubernetes.

This means that you can execute the following shell scripts and it will create a kubernetes secret in the pre-defined namespace when you created the asset the following shell script and it will create a kubernetes secret in the pre-defined namespace when you created the asset.

#### Creating oidcClientSecret.txt Secret

```
./create-oidc-<clientId>-secret.sh
secret/oidc-<clientId>
```
