#!/bin/sh

# Secrets for Confluent Platform
source $BASE_DIR/generated/ssl/cmd/kafkacontroller/create-tls-kafkacontroller-secret.sh
source $BASE_DIR/generated/ssl/cmd/kafkabroker/create-tls-kafkabroker-secret.sh
source $BASE_DIR/generated/ssl/cmd/kafkarestclass/create-tls-kafkarestclass-secret.sh
source $BASE_DIR/generated/ssl/cmd/keypair/create-mds-keypair.sh
source $BASE_DIR/generated/userstore/cmd/create-cleartext-userstore-secret.sh

source $BASE_DIR/generated/creds/sasl-plain/server-side/cmd/create-server-sasl-plain-json-kafkabroker-secret.sh

source $BASE_DIR/generated/creds/oidc/cmd/create-oidc-controlcenter-secret.sh
source $BASE_DIR/generated/creds/oauth/cmd/create-sasl-oauth-txt-kafkacontroller-secret.sh
source $BASE_DIR/generated/creds/oauth/cmd/create-sasl-oauth-txt-kafkabroker-secret.sh
source $BASE_DIR/generated/creds/oauth/cmd/create-sasl-oauth-txt-kafkarestclass-secret.sh

# Secrets for Confluent Gateway
source $BASE_DIR/generated/ssl/cmd/gateway/create-tls-gateway-secret.sh
source $BASE_DIR/generated/ssl/cmd/gateway/create-jks-gateway-secret.sh

source $BASE_DIR/generated/creds/gateway/client/cmd/create-gateway-client-plain-jaas-secret.sh
source $BASE_DIR/generated/creds/gateway/client/cmd/create-gateway-client-plain-json-secret.sh

source $BASE_DIR/generated/creds/gateway/client/cmd/create-gateway-client-scram-admin-secret.sh

source $BASE_DIR/generated/creds/gateway/cluster/cmd/create-gateway-cluster-oauth-secret.sh
source $BASE_DIR/generated/creds/gateway/client/cmd/create-gateway-client-oauth-jaas-secret.sh

source $BASE_DIR/generated/creds/gateway/cluster/cmd/create-gateway-cluster-plain-secret.sh

source $BASE_DIR/generated/creds/gateway/userstore/cmd/create-gateway-store-config-secret.sh
source $BASE_DIR/generated/creds/gateway/userstore/cmd/create-gateway-secret-store-secret.sh
source $BASE_DIR/generated/creds/gateway/userstore/cmd/create-gateway-anonymous-secret-swap-secret.sh
source $BASE_DIR/generated/creds/gateway/userstore/cmd/create-gateway-vault-config-secret.sh
