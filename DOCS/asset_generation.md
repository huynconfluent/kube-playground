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

## Generate SASL/DIGEST Assets

## Generate BASIC Auth Assets

## Generate File Based User Store Assets

## Generate MDS LDAP Bind User Asset

## Generate Bearer Auth Assets

## Generate OIDC Credential Secret
