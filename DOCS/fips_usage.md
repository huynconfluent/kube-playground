# FIPS Usage

Kube-Playground can generate FIPS related assets and deploy CFK when the optional flag is used.

## Deploying CFK with FIPs

We'll cover a typical CFK deployment with FIPs enabled

```
cd kube-playground
export BASE_DIR=$(pwd)
./start.sh -f
```

This will deploy CFK Operator with FIPS mode enabled, which can be verified in the Operator pod logs or in it's deployment.

From `confluent-operator` pod logs

```
{"level":"INFO","time":"2026-05-14T14:26:41.177Z","name":"setup","caller":"log/log.go:49","msg":"Fips mode is set to : ","FIPS mode":true}
```

From `confluent-operator` deployment

```
    spec:
      containers:
      - args:
        - --debug=false
        - --fipsmode=true
        - --kraftClusterIdRecovery=true
```

At this point you are able to deploy components with FIPs mode enabled or not per the component. For example. In order to Deploy Kafka with FIPs, we will need to enable it in the Kafka CR.

```
spec:
  fips:
    enabled: true
    # NOTE in CFK 3.2.0 there's an additional parameter that can be configured
    # mode: fips-140-2|fips-140-3
```

Along with this you will need to ensure that the appropriate TLS configuration using Secrets references Kubernetes Secrets which contain the `.bcfks` style keystore and truststores.

## Deploy TLS assets with FIPs.

If this is not a first time run and you already have pre-generated TLS assets, you can re-generate them providing the `-f` flag to generate the FIPS assets.
What this will do is download the necessary `.jar` file into the `generated` directory and use that to create the `.bcfks` files

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/helper/deploy-ssl.sh -c -f
```

Taking a look at the `generated` directory we should now see the following (using only kafkabroker as an example)

```
...
jars/
jars/bc-fips-1.0.2.3.jar
ssl/
ssl/cmd/kafkabroker/create-bcfks-kafkabroker-secret.sh
ssl/cmd/kafkabroker/create-jks-kafkabroker-secret.sh
ssl/cmd/kafkabroker/create-tls-kafkabroker-secret.sh
ssl/files/kafkabroker.keystore.bcfks
ssl/files/kafkabroker.keystore.jks
ssl/files/kafkabroker.keystore.jksPassword.txt
ssl/files/kafkabroker.keystore.p12
ssl/files/kafkabroker.truststore.bcfks
ssl/files/kafkabroker.truststore.jks
ssl/files/kafkabroker.truststore.jksPassword.txt
ssl/files/kafkabroker.truststore.p12
...
```

### Validation

You can inspecet the `.bcfks` keystores using keytool command just like in our Public Documentation

```
keytool -list -v \
  -keystore $BASE_DIR/generated/ssl/files/kafkabroker.keystore.bcfks \
  -storetype bcfks \
  -providerclass org.bouncycastle.jcajce.provider.BouncyCastleFipsProvider \
  -providerpath $BASE_DIR/generated/jars/bc-fips-1.0.2.3.jar \
  -storepass topsecret
```

Which should return something like

```
Keystore type: BCFKS
Keystore provider: BCFIPS

Your keystore contains 1 entry

Alias name: 1
Creation date: May 14, 2026
Entry type: PrivateKeyEntry
Certificate chain length: 3
Certificate[1]:
Owner: CN=kafkabroker, OU=Global Technical Support, O=Confluent Demo, C=US
Issuer: CN=GTS Intermediate X1, O=Confluent Demo, C=US
Serial number: 1d9a2a26c7ae0ca8bfefe30279dec08ed1cfedce
```

## Kubernetes Secrets

Like the other generated assets, we also generate a bash script to allow for repeated creation of the kubernetes secret.

For example, let's deploy our kafkabroker kubernetes secrets.

```
export BASE_DIR=$(pwd)
source $BASE_DIR/generated/ssl/cmd/kafkabroker/create-bcfks-kafkabroker-secret.sh
```

This will result in the following secret being created in the `confluent` namespace

```
secret/bcfks-kafkabroker
```

Now we can inspect this secret to see it has the following keys

```
kubectl -n confluent get secret bcfks-kafkabroker -o yaml
```

```
apiVersion: v1
data:
  jksPassword.txt: ..............
  keystore.bcfks: ..............
  keystore.jks: ..............
  truststore.bcfks: ..............
  truststore.jks: ..............
```

## Deploy Confluent Components using bcfks TLS

This will be brief. With FIPS enabled at the Component level, the `tls.secretRef` needs to specify our specific `bcfks-xxxx` secrets instead.

So for example, if we take an existing Kafka Listener configuration using the kubernetes secret which only contains PEM certs

```
spec:
  ......
  listeners:
    internal:
      authentication:
        type: mtls
        mtls:
          principalMappingRules:
            - RULE:^.*[Cc][Nn]=([a-zA-Z0-9.-]*).*$/$1/L,DEFAULT
          sslClientAuthentication: required
      tls:
        enabled: true
        secretRef: tls-kafkabroker
```

We can then swap out this with the `bcfks-kafkabroker` secret containing our fips enabled keystore files along with their jks/p12 keystore files.

```
spec:
  ......
  listeners:
    internal:
      authentication:
        type: mtls
        mtls:
          principalMappingRules:
            - RULE:^.*[Cc][Nn]=([a-zA-Z0-9.-]*).*$/$1/L,DEFAULT
          sslClientAuthentication: required
      tls:
        enabled: true
        secretRef: bcfks-kafkabroker
```
