# Confluent Gateway Example

This is an example of Confluent Gateway Deployment with Authentication Swapping and Authentication Passthrough.

Authentication Swap Scenarios are shown below

- [NONE -> SASL/PLAIN](#deploy-confluent-gateway-authentication-swap-none---saslplain)
- [SASL/PLAIN -> SASL/PLAIN](#deploy-confluent-gateway-authentication-swap-saslplain---saslplain)
- [SASL/PLAIN -> SASL/OAUTH](#deploy-confluent-gateway-authentication-swap-saslplain---sasloauth)
- [SASL/SCRAM (Stored in Vault) -> SASL/PLAIN](#deploy-confluent-gateway-authentication-swap-saslscram---saslplain)
- [SASL/SCRAM (Stored in Vault) -> SASL/OAUTH](#deploy-confluent-gateway-authentication-swap-saslscram---sasloauth)
- [mTLS -> SASL/PLAIN](#deploy-confluent-gateway-authentication-swap-mtls---saslplain)
- [mTLS -> SASL/OAUTH](#deploy-confluent-gateway-authentication-swap-mtls---sasloauth)
- [SASL/OAUTH -> SASL/OAUTH](#deploy-confluent-gateway-authentication-swap-sasloauth---sasloauth)
- [SASL/OAUTH -> SASL/PLAIN](#deploy-confluent-gateway-authentication-swap-sasloauth---saslplain)

Identity (Authentication) Passthrough Scenarios are shown below

- [SASL/PLAIN](#deploy-confluent-gateway-authentication-passthrough-saslplain)
- [SASL/SCRAM](#deploy-confluent-gateway-authentication-passthrough-saslscram)
- [SASL/OAUTH](#deploy-confluent-gateway-authentication-passthrough-sasloauth)

> [!NOTE]
> There a slight variation to the base deployments, particularly with CP deployment and if an IDP is required.

Here we are specifically using CFK 3.3.0 and CP 8.3.0 for the below examples. Kafka Deployment is done without `externalAccess`, only Confluent Gateway is being exposed externally.

## Start

1.a. Start kube-playground (File Based MDS)

```
cd kube-playground
export BASE_DIR=$(pwd)
./start.sh -v 3.3.0 -e vault
```

1.b. Start kube-playground (OAUTH Based MDS)

```
cd kube-playground
export BASE_DIR=$(pwd)
./start.sh -v 3.3.0 -e idp,vault
```

2. Deploy Kubernertes Secrets

```
cd examples/gateway/on-prem
./setup.sh
```

3.a. Deploy Kraft Controllers and Kafka Brokers (File Based MDS)

```
kubectl apply -f confluent-platform-base-file.yaml
```

3.b. Deploy Kraft Controllers and Kafka Brokers (OAUTH Based MDS)

```
kubectl apply -f confluent-platform-base-oauth.yaml
```

4. Deploy Rolebindings

This will create our rolebindings for our Kafka Cluster Principals.

```
kubectl apply -f rolebindings.yaml
```

From here we can follow through with the different Gateway Deployment Scenarios below

5. Create Kafka Topic

This will create our `kafkacli-test-topic` via CFK CR.

```
kubectl apply -f topic.yaml
```

## Deploy Confluent Gateway Authentication Swap (NONE -> SASL/PLAIN)

1. Using the File Based MDS deployment above, we can deploy the following Confluent Gateway Example

```
kubectl apply -f gateway-swap-file-none-plain.yaml
```

2. Adding Host Records for ExternalAccess

```
../../../scripts/helper/add-hosts-records.sh
```

3. Test `kafka-topics` to `gateway.confluentdemo.io:9092`

We can now use a `kafka-topics`, `kafka-console-producer` or `kafka-console-consumer` cli tool against the Confluent Gateway Endpoint.

```
kafka-topics --bootstrap-server gateway.confluentdemo.io:9092 --list
```

```
kafka-console-producer --bootstrap-server gateway.confluentdemo.io:9092 --topic anonymous-test-topic
```

```
kafka-console-consumer --bootstrap-server gateway.confleuntdemo.io:9092 --topic anonymous-test-topic --from-beginning
```

## Deploy Confluent Gateway Authentication Swap (SASL/PLAIN -> SASL/PLAIN)

1. Using the File Based MDS deployment above, we can deploy the following Confluent Gateway Example

```
kubectl apply -f gateway-swap-file-plain-plain.yaml
```

2. Adding Host Records for ExternalAccess

```
../../../scripts/helper/add-hosts-records.sh
```

3. Create our PLAIN User Client Properties File

We'll need to create our `kafkacli-gateway` Client Properties File.

```
sasl.mechanism=PLAIN
security.protocol=SASL_SSL
ssl.truststore.location=/<ABSOLUTE_PATH_TO>/kube-playground/generated/ssl/files/kafkacli-gateway.truststore.jks
ssl.truststore.password=topsecret
group.id=kafkacli-app
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
  username="kafkacli-gateway" \
  password="kafkacli-gateway-secret";
```

4. Test `kafka-topics` to `gateway.confluentdemo.io:9092`

We can now use a `kafka-topics`, `kafka-console-producer` or `kafka-console-consumer` cli tool against the Confluent Gateway Endpoint.

```
kafka-topics --bootstrap-server gateway.confluentdemo.io:9092 --list --command-config client_configs/client-kafkacli-plain.properties
```

```
kafka-console-producer --bootstrap-server gateway.confluentdemo.io:9092 --producer.config client_configs/client-kafkacli-plain.properties --topic kafkacli-test-topic
```

```
kafka-console-consumer --bootstrap-server gateway.confleuntdemo.io:9092 --consumer.config client_configs/client-kafkacli-plain.properties --topic kafkacli-test-topic --from-beginning
```

## Deploy Confluent Gateway Authentication Swap (SASL/PLAIN -> SASL/OAUTH)

1. Using the OAUTH Based MDS deployment above, we can deploy the following Confluent Gateway Example

```
kubectl apply -f gateway-swap-file-plain-oauth.yaml
```

2. Adding Host Records for ExternalAccess

```
../../../scripts/helper/add-hosts-records.sh
```

3. Create our PLAIN User Client Properties File

We'll need to create our `kafkacli-gateway` Client Properties File.

```
sasl.mechanism=PLAIN
security.protocol=SASL_SSL
ssl.truststore.location=/<ABSOLUTE_PATH_TO>/kube-playground/generated/ssl/files/kafkacli-gateway.truststore.jks
ssl.truststore.password=topsecret
group.id=kafkacli-app
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
  username="kafkacli-gateway" \
  password="kafkacli-gateway-secret";
```

4. Test `kafka-topics` to `gateway.confluentdemo.io:9092`

We can now use a `kafka-topics`, `kafka-console-producer` or `kafka-console-consumer` cli tool against the Confluent Gateway Endpoint.

```
kafka-topics --bootstrap-server gateway.confluentdemo.io:9092 --list --command-config client_configs/client-kafkacli-plain.properties
```

```
kafka-console-producer --bootstrap-server gateway.confluentdemo.io:9092 --producer.config client_configs/client-kafkacli-plain.properties --topic kafkacli-test-topic
```

```
kafka-console-consumer --bootstrap-server gateway.confleuntdemo.io:9092 --consumer.config client_configs/client-kafkacli-plain.properties --topic kafkacli-test-topic --from-beginning
```

## Deploy Confluent Gateway Authentication Swap (SASL/SCRAM -> SASL/PLAIN)

> [!NOTE]
> This Scenario requires Hashicorp Vault for the Secret Store.

1. Using the Vault Setup and File Based MDS deployment above, we can deploy the following Confluent Gateway Example

```
kubectl apply -f gateway-swap-vault-scram-plain.yaml
```

2. Adding Host Records for ExternalAccess

```
../../../scripts/helper/add-hosts-records.sh
```

3. Add our SCRAM Admin Credential into Vault

```
kubectl -n hashicorp exec -ti vault-0 -- vault kv put secret/confluent-gateway value=confluent-gateway/confluent-gateway-secret
```

4. Add our SCRAM Swap Credential into Vault

```
kubectl -n hashicorp exec -ti vault-0 -- vault kv put secret/kafkacli-gateway value=kafkacli/kafkacli-secret
```

5. Create SCRAM Admin Client Properties File

We'll need to manually create file `client-admin-scram.properties` this on our local machine to use to interact with Gateway to add our SCRAM user `kafkacli-gateway`

```
sasl.mechanism=SCRAM-SHA-256
security.protocol=SASL_SSL
ssl.truststore.location=/<ABSOLUTE_PATH_TO>/kube-playground/generated/ssl/files/confluent-gateway.truststore.jks
ssl.truststore.password=topsecret
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="confluent-gateway" \
  password="confluent-gateway-secret";
```

6. Create SCRAM User credential in Gateway

```
kafka-configs \
  --bootstrap-server gateway.confluentdemo.io:9092 \
  --command-config client-admin-scram.properties \
  --alter \
  --add-config "SCRAM-SHA-256=[iterations=8192,password=kafkacli-gateway-secret]" \
  --entity-type users \
  --entity-name kafkacli-gateway
```

7. Create our SCRAM User Client Properties File

We'll need to create our `kafkacli-gateway` Client Properties File.

```
sasl.mechanism=SCRAM-SHA-256
security.protocol=SASL_SSL
ssl.truststore.location=/<ABSOLUTE_PATH_TO>/kube-playground/generated/ssl/files/kafkacli-gateway.truststore.jks
ssl.truststore.password=topsecret
group.id=kafkacli-app
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="kafkacli-gateway" \
  password="kafkacli-gateway-secret";
```

8. Test `kafka-topics` to `gateway.confluentdemo.io:9092`

We can now use a `kafka-topics`, `kafka-console-producer` or `kafka-console-consumer` cli tool against the Confluent Gateway Endpoint.

```
kafka-topics --bootstrap-server gateway.confluentdemo.io:9092 --list --command-config client_configs/client-kafkacli-scram.properties
```

```
kafka-console-producer --bootstrap-server gateway.confluentdemo.io:9092 --producer.config client_configs/client-kafkacli-scram.properties --topic kafkacli-test-topic
```

```
kafka-console-consumer --bootstrap-server gateway.confleuntdemo.io:9092 --consumer.config client_configs/client-kafkacli-scram.properties --topic kafkacli-test-topic --from-beginning
```

## Deploy Confluent Gateway Authentication Swap (SASL/SCRAM -> SASL/OAUTH)

> [!NOTE]
> This Scenario requires Hashicorp Vault for the Secret Store.

1. Using the Vault Setup and OAUTH Based MDS deployment above, we can deploy the following Confluent Gateway Example

```
kubectl apply -f gateway-swap-vault-scram-oauth.yaml
```

2. Adding Host Records for ExternalAccess

```
../../../scripts/helper/add-hosts-records.sh
```

3. Add our SCRAM Admin Credential into Vault

```
kubectl -n hashicorp exec -ti vault-0 -- vault kv put secret/confluent-gateway value=confluent-gateway/confluent-gateway-secret
```

4. Add our SCRAM Swap Credential into Vault

```
kubectl -n hashicorp exec -ti vault-0 -- vault kv put secret/kafkacli-gateway value=kafkacli/kafkacli-secret
```

5. Create SCRAM Admin Client Properties File

We'll need to manually create file `client-admin-scram.properties` this on our local machine to use to interact with Gateway to add our SCRAM user `kafkacli-gateway`

```
sasl.mechanism=SCRAM-SHA-256
security.protocol=SASL_SSL
ssl.truststore.location=/<ABSOLUTE_PATH_TO>/kube-playground/generated/ssl/files/confluent-gateway.truststore.jks
ssl.truststore.password=topsecret
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="confluent-gateway" \
  password="confluent-gateway-secret";
```

6. Create SCRAM User credential in Gateway

```
kafka-configs \
  --bootstrap-server gateway.confluentdemo.io:9092 \
  --command-config client-admin-scram.properties \
  --alter \
  --add-config "SCRAM-SHA-256=[iterations=8192,password=kafkacli-gateway-secret]" \
  --entity-type users \
  --entity-name kafkacli-gateway
```

7. Create our SCRAM User Client Properties File

We'll need to create our `kafkacli-gateway` Client Properties File.

```
sasl.mechanism=SCRAM-SHA-256
security.protocol=SASL_SSL
ssl.truststore.location=/<ABSOLUTE_PATH_TO>/kube-playground/generated/ssl/files/kafkacli-gateway.truststore.jks
ssl.truststore.password=topsecret
group.id=kafkacli-app
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="kafkacli-gateway" \
  password="kafkacli-gateway-secret";
```

8. Test `kafka-topics` to `gateway.confluentdemo.io:9092`

We can now use a `kafka-topics`, `kafka-console-producer` or `kafka-console-consumer` cli tool against the Confluent Gateway Endpoint.

```
kafka-topics --bootstrap-server gateway.confluentdemo.io:9092 --list --command-config client_configs/client-kafkacli-scram.properties
```

```
kafka-console-producer --bootstrap-server gateway.confluentdemo.io:9092 --producer.config client_configs/client-kafkacli-scram.properties --topic kafkacli-test-topic
```

```
kafka-console-consumer --bootstrap-server gateway.confleuntdemo.io:9092 --consumer.config client_configs/client-kafkacli-scram.properties --topic kafkacli-test-topic --from-beginning
```

## Deploy Confluent Gateway Authentication Swap (mTLS -> SASL/PLAIN)

1. Using the File Based MDS deployment above, we can deploy the following Confluent Gateway Example

```
kubectl apply -f gateway-swap-file-mtls-plain.yaml
```

2. Adding Host Records for ExternalAccess

```
../../../scripts/helper/add-hosts-records.sh
```

3. Create our MTLS User Client Properties File

We'll need to create our `kafkacli-gateway` Client Properties File.

```
security.protocol=SSL
ssl.keystore.location=/<ABSOLUTE_PATH_TO>/kube-playground/generated/ssl/files/kafkacli-gateway.keystore.jks
ssl.keystore.password=topsecret
ssl.key.password=topsecret
ssl.truststore.location=/<ABSOLUTE_PATH_TO>/kube-playground/generated/ssl/files/kafkacli-gateway.truststore.jks
ssl.truststore.password=topsecret
group.id=kafkacli-app
```

4. Test `kafka-topics` to `gateway.confluentdemo.io:9092`

We can now use a `kafka-topics`, `kafka-console-producer` or `kafka-console-consumer` cli tool against the Confluent Gateway Endpoint.

```
kafka-topics --bootstrap-server gateway.confluentdemo.io:9092 --list --command-config client_configs/client-kafkacli-mtls.properties
```

```
kafka-console-producer --bootstrap-server gateway.confluentdemo.io:9092 --producer.config client_configs/client-kafkacli-mtls.properties --topic kafkacli-test-topic
```

```
kafka-console-consumer --bootstrap-server gateway.confleuntdemo.io:9092 --consumer.config client_configs/client-kafkacli-mtls.properties --topic kafkacli-test-topic --from-beginning
```

## Deploy Confluent Gateway Authentication Swap (mTLS -> SASL/OAUTH)

1. Using the OAUTH Based MDS deployment above, we can deploy the following Confluent Gateway Example

```
kubectl apply -f gateway-swap-file-mtls-oauth.yaml
```

2. Adding Host Records for ExternalAccess

```
../../../scripts/helper/add-hosts-records.sh
```

3. Create our MTLS User Client Properties File

We'll need to create our `kafkacli-gateway` Client Properties File.

```
security.protocol=SSL
ssl.keystore.location=/<ABSOLUTE_PATH_TO>/kube-playground/generated/ssl/files/kafkacli-gateway.keystore.jks
ssl.keystore.password=topsecret
ssl.key.password=topsecret
ssl.truststore.location=/<ABSOLUTE_PATH_TO>/kube-playground/generated/ssl/files/kafkacli-gateway.truststore.jks
ssl.truststore.password=topsecret
group.id=kafkacli-app
```

4. Test `kafka-topics` to `gateway.confluentdemo.io:9092`

We can now use a `kafka-topics`, `kafka-console-producer` or `kafka-console-consumer` cli tool against the Confluent Gateway Endpoint.

```
kafka-topics --bootstrap-server gateway.confluentdemo.io:9092 --list --command-config client_configs/client-kafkacli-mtls.properties
```

```
kafka-console-producer --bootstrap-server gateway.confluentdemo.io:9092 --producer.config client_configs/client-kafkacli-mtls.properties --topic kafkacli-test-topic
```

```
kafka-console-consumer --bootstrap-server gateway.confleuntdemo.io:9092 --consumer.config client_configs/client-kafkacli-mtls.properties --topic kafkacli-test-topic --from-beginning
```

## Deploy Confluent Gateway Authentication Swap (SASL/OAUTH -> SASL/OAUTH)

1. Using the OAUTH Based MDS deployment above, we can deploy the following Confluent Gateway Example

```
kubectl apply -f gateway-swap-file-oauth-oauth.yaml
```

2. Adding Host Records for ExternalAccess

```
../../../scripts/helper/add-hosts-records.sh
```

3. Create our OAUTH User Client Properties File

We'll need to create our `kafkacli-gateway` Client Properties File.

```
sasl.mechanism=OAUTHBEARER
security.protocol=SASL_SSL
ssl.truststore.location=/<ABSOLUTE_PATH_TO>/kube-playground/generated/ssl/files/kafkacli-gateway.truststore.jks
ssl.truststore.password=topsecret
group.id=kafkacli-app
sasl.oauthbearer.token.endpoint.url=https://keycloak.confluentdemo.io/realms/confluentdemo/protocol/openid-connect/token
sasl.login.callback.handler.class=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginCallbackHandler
sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required \
    clientId="kafkacli-gateway" \
    clientSecret="kafkacli-gateway-secret";
```

4. Test `kafka-topics` to `gateway.confluentdemo.io:9092`

We can now use a `kafka-topics`, `kafka-console-producer` or `kafka-console-consumer` cli tool against the Confluent Gateway Endpoint.

> [!NOTE]
> We will need to export `KAFKA_OPTS` first to account for IDP endpoint

```
export KAFKA_OPTS="-Dorg.apache.kafka.sasl.oauthbearer.allowed.urls=* -Djavax.net.ssl.trustStore=/<PATH_TO_KUBE_PLAYGROUND>/generated/ssl/files/kafkacli-gateway.truststore.jks -Djavax.net.ssl.trustStorePassword=topsecret"
```

```
kafka-topics --bootstrap-server gateway.confluentdemo.io:9092 --list --command-config client_configs/client-kafkacli-oauth.properties
```

```
kafka-console-producer --bootstrap-server gateway.confluentdemo.io:9092 --producer.config client_configs/client-kafkacli-oauth.properties --topic kafkacli-test-topic
```

```
kafka-console-consumer --bootstrap-server gateway.confleuntdemo.io:9092 --consumer.config client_configs/client-kafkacli-oauth.properties --topic kafkacli-test-topic --from-beginning
```

## Deploy Confluent Gateway Authentication Swap (SASL/OAUTH -> SASL/PLAIN)

1. Using the File Based MDS deployment above, we can deploy the following Confluent Gateway Example

```
kubectl apply -f gateway-swap-file-plain-plain.yaml
```

2. Adding Host Records for ExternalAccess

```
../../../scripts/helper/add-hosts-records.sh
```

3. Create our OAUTH User Client Properties File

We'll need to create our `kafkacli-gateway` Client Properties File.

```
sasl.mechanism=OAUTHBEARER
security.protocol=SASL_SSL
ssl.truststore.location=/<ABSOLUTE_PATH_TO>/kube-playground/generated/ssl/files/kafkacli-gateway.truststore.jks
ssl.truststore.password=topsecret
group.id=kafkacli-app
sasl.oauthbearer.token.endpoint.url=https://keycloak.confluentdemo.io/realms/confluentdemo/protocol/openid-connect/token
sasl.login.callback.handler.class=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginCallbackHandler
sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required \
    clientId="kafkacli-gateway" \
    clientSecret="kafkacli-gateway-secret";
```

4. Test `kafka-topics` to `gateway.confluentdemo.io:9092`

We can now use a `kafka-topics`, `kafka-console-producer` or `kafka-console-consumer` cli tool against the Confluent Gateway Endpoint.

```
kafka-topics --bootstrap-server gateway.confluentdemo.io:9092 --list --command-config client_configs/client-kafkacli-oauth.properties
```

```
kafka-console-producer --bootstrap-server gateway.confluentdemo.io:9092 --producer.config client_configs/client-kafkacli-oauth.properties --topic kafkacli-test-topic
```

```
kafka-console-consumer --bootstrap-server gateway.confleuntdemo.io:9092 --consumer.config client_configs/client-kafkacli-oauth.properties --topic kafkacli-test-topic --from-beginning
```

## Deploy Confluent Gateway Authentication Passthrough SASl/PLAIN

1. Using the File Based MDS deployment above, we can deploy the following Confluent Gateway Example

```
kubectl apply -f gateway-passthrough-sasl-plain.yaml
```

2. Adding Host Records for ExternalAccess

```
../../../scripts/helper/add-hosts-records.sh
```

3. Create our PLAIN User Client Properties File

We'll need to create our `kafkacli` Client Properties File.

```
sasl.mechanism=PLAIN
security.protocol=SASL_SSL
ssl.truststore.location=/<ABSOLUTE_PATH_TO>/kube-playground/generated/ssl/files/kafkacli.truststore.jks
ssl.truststore.password=topsecret
group.id=kafkacli-app
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
  username="kafkacli" \
  password="kafkacli-secret";
```

4. Test `kafka-topics` to `gateway.confluentdemo.io:9092`

We can now use a `kafka-topics`, `kafka-console-producer` or `kafka-console-consumer` cli tool against the Confluent Gateway Endpoint.

```
kafka-topics --bootstrap-server gateway.confluentdemo.io:9092 --list --command-config client_configs/client-kafkacli-plain.properties
```

```
kafka-console-producer --bootstrap-server gateway.confluentdemo.io:9092 --producer.config client_configs/client-kafkacli-plain.properties --topic kafkacli-test-topic
```

```
kafka-console-consumer --bootstrap-server gateway.confleuntdemo.io:9092 --consumer.config client_configs/client-kafkacli-plain.properties --topic kafkacli-test-topic --from-beginning
```

## Deploy Confluent Gateway Authentication Passthrough SASl/SCRAM

1. Using the File Based MDS deployment above, we can deploy the following Confluent Gateway Example

```
kubectl apply -f gateway-passthrough-sasl-scram.yaml
```

2. Adding Host Records for ExternalAccess

```
../../../scripts/helper/add-hosts-records.sh
```

3. Create Kafkabroker mTLS Properties File inside Broker Pod

We'll need to manually create file `kafkabroker-mtls.properties` in one of the kafkabroker pods, this will be necessary to add our SCRAM user before gateway clients can interact.

```
cat > /tmp/kafkabroker-mtls.properties << 'EOF'
security.protocol=SSL
ssl.keystore.location=/mnt/sslcerts/tls-kafkabroker/keystore.p12
ssl.keystore.password=mystorepassword
ssl.key.password=mystorepassword
ssl.truststore.location=/mnt/sslcerts/tls-kafkabroker/truststore.p12
ssl.truststore.password=mystorepassword
EOF
```

4. Add our SCRAM user using the Kafkabroker Client Properties inside the Broker Pod

Here we'll add our passthrough client credentials. User will be `kafkacli` here.

```
kafka-configs \
  --bootstrap-server kafkabroker.confluent.svc.cluster.local:9996 \
  --command-config /tmp/kafkabroker-mtls.properties \
  --alter \
  --add-config "SCRAM-SHA-256=[iterations=8192,password=kafkacli-secret]" \
  --entity-type users \
  --entity-name kafkacli
```

5. Create our SCRAM User Client Properties File

We'll need to create our `kafkacli` Client Properties File.

```
sasl.mechanism=SCRAM-SHA-256
security.protocol=SASL_SSL
ssl.truststore.location=/<ABSOLUTE_PATH_TO>/kube-playground/generated/ssl/files/kafkacli.truststore.jks
ssl.truststore.password=topsecret
group.id=kafkacli-app
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="kafkacli" \
  password="kafkacli-secret";
```

6. Test `kafka-topics` to `gateway.confluentdemo.io:9092`

We can now use a `kafka-topics`, `kafka-console-producer` or `kafka-console-consumer` cli tool against the Confluent Gateway Endpoint.

```
kafka-topics --bootstrap-server gateway.confluentdemo.io:9092 --list --command-config client_configs/client-kafkacli-scram.properties
```

```
kafka-console-producer --bootstrap-server gateway.confluentdemo.io:9092 --producer.config client_configs/client-kafkacli-scram.properties --topic kafkacli-test-topic
```

```
kafka-console-consumer --bootstrap-server gateway.confleuntdemo.io:9092 --consumer.config client_configs/client-kafkacli-scram.properties --topic kafkacli-test-topic --from-beginning
```

## Deploy Confluent Gateway Authentication Passthrough SASl/OAUTH

1. Using the OAUTH Based MDS deployment above, we can deploy the following Confluent Gateway Example

```
kubectl apply -f gateway-passthrough-sasl-oauth.yaml
```

2. Adding Host Records for ExternalAccess

```
../../../scripts/helper/add-hosts-records.sh
```

3. Create our OAUTH User Client Properties File

We'll need to create our `kafkacli` Client Properties File.

```
sasl.mechanism=OAUTHBEARER
security.protocol=SASL_SSL
ssl.truststore.location=/<ABSOLUTE_PATH_TO>/kube-playground/generated/ssl/files/kafkacli.truststore.jks
ssl.truststore.password=topsecret
group.id=kafkacli-app
sasl.oauthbearer.token.endpoint.url=https://keycloak.confluentdemo.io/realms/confluentdemo/protocol/openid-connect/token
sasl.login.callback.handler.class=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginCallbackHandler
sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required \
    clientId="kafkacli" \
    clientSecret="kafkacli-secret";
```

4. Test `kafka-topics` to `gateway.confluentdemo.io:9092`

We can now use a `kafka-topics`, `kafka-console-producer` or `kafka-console-consumer` cli tool against the Confluent Gateway Endpoint.

> [!NOTE]
> We don't need to export `KAFKA_OPTS` for the IDP Point, because this is already done by our brokers.

```
kafka-topics --bootstrap-server gateway.confluentdemo.io:9092 --list --command-config client_configs/client-kafkacli-oauth.properties
```

```
kafka-console-producer --bootstrap-server gateway.confluentdemo.io:9092 --producer.config client_configs/client-kafkacli-oauth.properties --topic kafkacli-test-topic
```

```
kafka-console-consumer --bootstrap-server gateway.confleuntdemo.io:9092 --consumer.config client_configs/client-kafkacli-oauth.properties --topic kafkacli-test-topic --from-beginning
```
