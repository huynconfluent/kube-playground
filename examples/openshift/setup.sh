#!/bin/sh

source $BASE_DIR/generated/ssl/cmd/keypair/create-mds-keypair.sh oc
source $BASE_DIR/generated/ssl/cmd/kafkacontroller/create-tls-kafkacontroller-secret.sh oc
source $BASE_DIR/generated/ssl/cmd/kafkabroker/create-tls-kafkabroker-secret.sh oc
source $BASE_DIR/generated/ssl/cmd/kafkarestclass/create-tls-kafkarestclass-secret.sh oc
source $BASE_DIR/generated/ssl/cmd/connect/create-tls-connect-secret.sh oc
source $BASE_DIR/generated/ssl/cmd/schemaregistry/create-tls-schemaregistry-secret.sh oc
source $BASE_DIR/generated/ssl/cmd/kafkarestproxy/create-tls-kafkarestproxy-secret.sh oc
source $BASE_DIR/generated/ssl/cmd/controlcenter/create-tls-controlcenter-secret.sh oc

source $BASE_DIR/generated/creds/oidc/cmd/create-oidc-controlcenter-secret.sh oc

source $BASE_DIR/generated/creds/oauth/cmd/create-sasl-oauth-txt-controlcenter-secret.sh oc
source $BASE_DIR/generated/creds/oauth/cmd/create-sasl-oauth-txt-kafkacontroller-secret.sh oc
source $BASE_DIR/generated/creds/oauth/cmd/create-sasl-oauth-txt-kafkabroker-secret.sh oc
source $BASE_DIR/generated/creds/oauth/cmd/create-sasl-oauth-txt-kafkarestclass-secret.sh oc
source $BASE_DIR/generated/creds/oauth/cmd/create-sasl-oauth-txt-connect-secret.sh oc
source $BASE_DIR/generated/creds/oauth/cmd/create-sasl-oauth-txt-schemaregistry-secret.sh oc
source $BASE_DIR/generated/creds/oauth/cmd/create-sasl-oauth-txt-kafkarestproxy-secret.sh oc
