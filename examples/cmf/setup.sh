#!/bin/sh

source $BASE_DIR/generated/ssl/cmd/keypair/create-mds-keypair.sh
source $BASE_DIR/generated/ssl/cmd/kafkacontroller/create-tls-kafkacontroller-secret.sh
source $BASE_DIR/generated/ssl/cmd/kafkabroker/create-tls-kafkabroker-secret.sh
source $BASE_DIR/generated/ssl/cmd/kafkarestclass/create-tls-kafkarestclass-secret.sh
source $BASE_DIR/generated/ssl/cmd/cmf/create-tls-cmf-secret.sh

source $BASE_DIR/generated/creds/oidc/cmd/create-oidc-controlcenter-secret.sh

source $BASE_DIR/generated/creds/oauth/cmd/create-sasl-oauth-txt-kafkacontroller-secret.sh
source $BASE_DIR/generated/creds/oauth/cmd/create-sasl-oauth-txt-kafkabroker-secret.sh
source $BASE_DIR/generated/creds/oauth/cmd/create-sasl-oauth-txt-kafkarestclass-secret.sh
source $BASE_DIR/generated/creds/oauth/cmd/create-sasl-oauth-txt-cmf-secret.sh

source $BASE_DIR/generated/creds/bearer/cmd/create-bearer-kafkarestclass-secret.sh
source $BASE_DIR/generated/creds/bearer/cmd/create-bearer-kafkabroker-secret.sh

source $BASE_DIR/generated/creds/mds/cmd/create-mds-binduser-secret.sh
