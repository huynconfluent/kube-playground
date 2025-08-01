#!/bin/sh

# Usage: ./deploy-ssl.sh
# This will auto generate a bunch of SSL files to be used in a CFK CP deplyoment

if [ -z "$BASE_DIR" ]; then
    echo "Please export BASE_DIR=\$(pwd)"
    exit 1
fi

set -o allexport; source $BASE_DIR/.env; set +o allexport

# Generate SSL files
CERT_CHAIN=1
BASE_SUBJECT="/C=US/ST=CA/O=Confluent Demo"
ORG_UNIT="OU=Global Technical Support"
GENERATED_DIR="$BASE_DIR/generated/ssl"
KEYSTORE_PASSWORD="topsecret"
SCRIPT_DIR="$BASE_DIR/scripts/ssl"
KUBE_SAN_BASE="DNS:localhost,DNS:*.$KUBE_BASEDOMAIN,DNS:*.$CFK_NAMESPACE.svc.cluster.local"
KUBE_IDENTITY_SAN_BASE="DNS:*.$IDENTITY_NAMESPACE.svc.cluster.local,DNS:*.openldap.$IDENTITY_NAMESPACE.svc.cluster.local,DNS:*.keycloak.$IDENTITY_NAMESPACE.svc.cluster.local,DNS:*.keycloak.$KUBE_BASEDOMAIN,DNS:*.openldap.$KUBE_BASEDOMAIN"
KUBE_CP_SAN_BASE="DNS:*.zookeeper.$CFK_NAMESPACE.svc.cluster.local,DNS:*.kraftcontroller.$CFK_NAMESPACE.svc.cluster.local,DNS:*.kafka.$CFK_NAMESPACE.svc.cluster.local,DNS:*.connect.$CFK_NAMESPACE.svc.cluster.local,DNS:*.schemaregistry.$CFK_NAMESPACE.svc.cluster.local,DNS:*.controlcenter.$CFK_NAMESPACE.svc.cluster.local,DNS:*.kafkarestproxy.$CFK_NAMESPACE.svc.cluster.local,DNS:*.ksqldb.$CFK_NAMESPACE.svc.cluster.local,DNS:*.replicator.$CFK_NAMESPACE.svc.cluster.local,DNS:*.zookeeper.$KUBE_BASEDOMAIN,DNS:*.kraftcontroller.$KUBE_BASEDOMAIN,DNS:*.kafka.$KUBE_BASEDOMAIN,DNS:*.connect.$KUBE_BASEDOMAIN,DNS:*.schemaregistry.$KUBE_BASEDOMAIN,DNS:*.kafkarestproxy.$KUBE_BASEDOMAIN,DNS:*.controlcenter.$KUBE_BASEDOMAIN,DNS:*.ksqldb.$KUBE_BASEDOMAIN,DNS:*.replicator.$KUBE_BASEDOMAIN"

generate_key_and_trust () {

    source $SCRIPT_DIR/create-user-cert.sh "$1" "$BASE_SUBJECT/$ORG_UNIT" "$SCRIPT_DIR/configs/component.cnf" \
    "$GENERATED_DIR/intermediate_ca/private/intermediate_$CERT_CHAIN.key" "$GENERATED_DIR/intermediate_ca/certs/intermediate-signed_$CERT_CHAIN.pem" \
    "$GENERATED_DIR/intermediate_ca/certs/fullchain.pem" "$2"
    source $SCRIPT_DIR/create-truststore.sh "$1" "$GENERATED_DIR/root_ca/certs/ca.pem" "$KEYSTORE_PASSWORD" "$GENERATED_DIR/files"
}

generate_bash_script () {
    component=$1
    fullchain=$2
    cacerts=$3
    privkey=$4

    eval $BASE_DIR/scripts/helper/generate-ssl-scripts.sh "$component" "$GENERATED_DIR" "$CFK_NAMESPACE" "$fullchain" "$cacerts" "$privkey"
}

generate_mds_bash_script () {

    cmd="kubectl -n $CFK_NAMESPACE create secret generic mds-keypair --from-file=mdsPublicKey.pem=$GENERATED_DIR/files/keypair/mds-keypair-public.pem --from-file=mdsTokenKeyPair.pem=$GENERATED_DIR/files/keypair/mds-keypair-private.pem"
    
    printf "\nKubectl Command: %s\n" "$cmd"

    if [ ! -d "$GENERATED_DIR/cmd/keypair" ]; then
        printf "\nMaking Command directory in %s\n" "$GENERATED_DIR/cmd/keypair"
        mkdir -p "$GENERATED_DIR/cmd/keypair"
    fi

    printf "#!/bin/sh\n%s\n" "$cmd" > $GENERATED_DIR/cmd/keypair/create-mds-keypair.sh
    chmod +x "$GENERATED_DIR/cmd/keypair/create-mds-keypair.sh"

    printf "\nCreated bash script at %s\n" "$GENERATED_DIR/cmd/keypair/create-mds-keypair.sh"
}

printf "\n===Checking for existing files===\n"
if [ -f "$GENERATED_DIR/root_ca/certs/ca.pem" ]; then
    printf "\nca.pem found in %s, likely ssl certs already generated, so skipping....\n" "$GENERATED_DIR/root_ca/certs"
else
    printf "\n====Creating SSL Certificates====\n"
    # Generating Root CA
    export WORK_DIR=$GENERATED_DIR/root_ca
    source $SCRIPT_DIR/create-ca.sh $SCRIPT_DIR/configs/root_ca.cnf "$BASE_SUBJECT/CN=Root X1"
    
    # Generating Intermediate CA
    export WORK_DIR=$GENERATED_DIR/intermediate_ca
    source $SCRIPT_DIR/create-intermediate-ca.sh $CERT_CHAIN "$BASE_SUBJECT/$ORG_UNIT/CN=Intermediate" $SCRIPT_DIR/configs/intermediate_ca.cnf $GENERATED_DIR/root_ca/private/ca.key $GENERATED_DIR/root_ca/certs/ca.pem
    
    # Generating Component Certs
    export WORK_DIR=$GENERATED_DIR/component GEN_DIR=$GENERATED_DIR/files
    
    generate_key_and_trust "keycloak" "DNS:keycloak,DNS:*.keycloak.$KUBE_BASEDOMAIN,$KUBE_IDENTITY_SAN_BASE,$KUBE_SAN_BASE"
    generate_key_and_trust "openldap" "DNS:openldap,DNS:*.openldap.$KUBE_BASEDOMAIN,$KUBE_IDENTITY_SAN_BASE,$KUBE_SAN_BASE"
    generate_key_and_trust "zookeeper" "DNS:zookeeper,DNS:zookeeper.$KUBE_BASEDOMAIN,$KUBE_CP_SAN_BASE,$KUBE_SAN_BASE"
    generate_key_and_trust "kraftcontroller" "DNS:kraftcontroller,DNS:kraftcontroller.$KUBE_BASEDOMAIN,$KUBE_CP_SAN_BASE,$KUBE_SAN_BASE"
    generate_key_and_trust "kafka" "DNS:kafka,DNS:kafka.$KUBE_BASEDOMAIN,$KUBE_CP_SAN_BASE,$KUBE_SAN_BASE"
    generate_key_and_trust "schemaregistry" "DNS:schemaregistry,DNS:schemaregistry.$KUBE_BASEDOMAIN,$KUBE_CP_SAN_BASE,$KUBE_SAN_BASE"
    generate_key_and_trust "connect" "DNS:connect,DNS:connect.$KUBE_BASEDOMAIN,$KUBE_CP_SAN_BASE,$KUBE_SAN_BASE"
    generate_key_and_trust "kafkarestproxy" "DNS:kafkarestproxy,DNS:kafkarestproxy.$KUBE_BASEDOMAIN,$KUBE_CP_SAN_BASE,$KUBE_SAN_BASE"
    generate_key_and_trust "replicator" "DNS:replicator,DNS:replicator.$KUBE_BASEDOMAIN,$KUBE_CP_SAN_BASE,$KUBE_SAN_BASE"
    generate_key_and_trust "ksqldb" "DNS:ksqldb,DNS:ksqldb.$KUBE_BASEDOMAIN,$KUBE_CP_SAN_BASE,$KUBE_SAN_BASE"
    generate_key_and_trust "controlcenter" "DNS:controlcenter,DNS:controlcenter.$KUBE_BASEDOMAIN,$KUBE_CP_SAN_BASE,$KUBE_SAN_BASE"
    
    printf "\nSSL Certificate Generation complete!\n"
    
    printf "\n=====Generating MDS Keypair======\n"
    
    export GEN_DIR=$BASE_DIR/generated/ssl
    source $BASE_DIR/scripts/ssl/create-mds-keypair.sh
    
    generate_mds_bash_script
    
    printf "\n\n====Generating Bash Scripts======\n"
    
    COMP="zookeeper kraftcontroller kafka schemaregistry connect kafkarestproxy replicator ksqldb controlcenter"
    
    for component in $COMP; do
    
        fullchain_path="$GENERATED_DIR/component/certs/$component-fullchain.pem"
        cacerts_path="$GENERATED_DIR/intermediate_ca/certs/fullchain.pem"
        privkey_path="$GENERATED_DIR/component/private/$component.key"
    
        generate_bash_script "$component" "$fullchain_path" "$cacerts_path" "$privkey_path"
    
    done
    
    printf "\n\n====Completed SSL Generation=====\n"
    printf "SSL Files and bash scripts for kubernetes secret creation have been generated....\n"
fi
