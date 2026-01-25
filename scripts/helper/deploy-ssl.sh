#!/bin/sh

# Usage: ./deploy-ssl.sh -c 
# This will auto generate a bunch of SSL files to be used in a CFK CP deplyoment

if [ -z "$BASE_DIR" ]; then
    echo "Please export BASE_DIR=\$(pwd)"
    exit 1
fi

set -o allexport; source $BASE_DIR/.env; set +o allexport

REQUIRED_PKG="keytool cfssl openssl"
# check for prerequisites
for PKG in $REQUIRED_PKG; do
    if [ -z "$(which ${PKG})" ]; then
        printf "REQUIRED: %s" "${PKG}"
        printf "\nPlease install %s" "${PKG}"
        printf "\nUsing Brew:"
        printf "\n\tbrew install %s" "${PKG}"
        exit 1
    fi
done

# A bunch of defaults
OPTIND=1
DEPLOY_CLEAN=false
CERT_CHAIN=1
CA_ROOT_NAME="GTS Root X"
CA_ROOT_BASE='{"C": "US","O": "Confluent Demo"}'
CA_EXPIRY="8760h"
CA_KEY_ALGO="rsa"
CA_KEY_SIZE="4096"
CA_INTERMEDIATE_NAME="GTS Intermediate X"
CA_INTERMEDIATE_BASE='{"C": "US","O": "Confluent Demo"}'
CA_INTERMEDIATE_EXPIRY="4380h"
CA_INTERMEDIATE_KEY_ALGO="rsa"
CA_INTERMEDIATE_KEY_SIZE="4096"
COMPONENT_BASE='{"C": "US","O":"Confluent Demo","OU":"Global Technical Support"}'
COMPONENT_EXPIRY="2190h"
COMPONENT_KEY_ALGO="rsa"
COMPONENT_KEY_SIZE="4096"

KEYSTORE_PASSWORD="topsecret"
TRUSTSTORE_PASSWORD="$KEYSTORE_PASSWORD"

KUBE_SAN_BASE="[\"localhost\",\"*.$KUBE_BASEDOMAIN\",\"*.$CFK_NAMESPACE.svc.cluster.local\"]"
KUBE_IDENTITY_SAN_BASE="[\"*.$IDENTITY_NAMESPACE.svc.cluster.local\",\"*.openldap.$IDENTITY_NAMESPACE.svc.cluster.local\",\"*.keycloak.$IDENTITY_NAMESPACE.svc.cluster.local\",\"*.keycloak.$KUBE_BASEDOMAIN\",\"*.openldap.$KUBE_BASEDOMAIN\"]"
KUBE_CP_SAN_BASE="[\"*.zookeeper.$CFK_NAMESPACE.svc.cluster.local\",\"*.kraftcontroller.$CFK_NAMESPACE.svc.cluster.local\",\"*.kafka.$CFK_NAMESPACE.svc.cluster.local\",\"*.connect.$CFK_NAMESPACE.svc.cluster.local\",\"*.schemaregistry.$CFK_NAMESPACE.svc.cluster.local\",\"*.controlcenter.$CFK_NAMESPACE.svc.cluster.local\",\"*.kafkarestproxy.$CFK_NAMESPACE.svc.cluster.local\",\"*.ksqldb.$CFK_NAMESPACE.svc.cluster.local\",\"*.replicator.$CFK_NAMESPACE.svc.cluster.local\",\"*.zookeeper.$KUBE_BASEDOMAIN\",\"*.kraftcontroller.$KUBE_BASEDOMAIN\",\"*.kafka.$KUBE_BASEDOMAIN\",\"*.connect.$KUBE_BASEDOMAIN\",\"*.schemaregistry.$KUBE_BASEDOMAIN\",\"*.kafkarestproxy.$KUBE_BASEDOMAIN\",\"*.controlcenter.$KUBE_BASEDOMAIN\",\"*.ksqldb.$KUBE_BASEDOMAIN\",\"*.replicator.$KUBE_BASEDOMAIN\"]"
KUBE_FLINK_SAN_BASE="[\"*.flink.$FLINK_NAMESPACE.svc.cluster.local\",\"*.flink.$KUBE_BASEDOMAIN\"]"

GENERATED_DIR="$BASE_DIR/generated/ssl"
SCRIPT_DIR="$BASE_DIR/scripts/ssl"

usage() {
    printf "Usage: $0 [-c]\n"
    printf "\t-c      (optional) clean deployment, delete and replace existing ssl assets\n"
    exit 1
}

while getopts "c" opt; do
    case $opt in
        c)
            DEPLOY_CLEAN=true
            ;;
        *)
            usage
            ;;
    esac
done

generate_key_and_trust () {

    # local variables
    l_name=$1
    l_base=$2
    l_san=$3
    l_expiry=$COMPONENT_EXPIRY
    l_key_algo=$COMPONENT_KEY_ALGO
    l_key_size=$COMPONENT_KEY_SIZE
    l_ca_cert=$4
    l_ca_key=$5
    l_cacerts="$GENERATED_DIR/files/cacerts.pem"
    l_profile="server_and_client"

    # Call user cert creation
    source $SCRIPT_DIR/create-user-cert.sh "$l_name" "$l_base" "$l_san" "$l_expiry" "$l_key_algo" "$l_key_size" "$l_ca_cert" "$l_ca_key" "$l_cacerts" "$l_profile"
    # Call keystore creation
    source $SCRIPT_DIR/create-keystore.sh "$l_name" "$GENERATED_DIR/components/$l_name-key.pem" "$GENERATED_DIR/components/$l_name-fullchain.pem" "$KEYSTORE_PASSWORD"
    # Call truststore creaction
    source $SCRIPT_DIR/create-truststore.sh "$l_name" "$l_cacerts" "$TRUSTSTORE_PASSWORD"
}

generate_tls_bash_script () {
    component=$1
    fullchain=$2
    cacerts=$3
    privkey=$4

    eval $BASE_DIR/scripts/helper/generate-ssl-pem-scripts.sh -c "$component" -d "$GENERATED_DIR" -n "$CFK_NAMESPACE" -f "$fullchain" -a "$cacerts" -p "$privkey"
}

generate_jks_bash_script () {
    component=$1
    keystore=$2
    truststore=$3
    passwordFile=$4

    eval $BASE_DIR/scripts/helper/generate-ssl-jks-scripts.sh -c "$component" -d "$GENERATED_DIR" -n "$CFK_NAMESPACE" -k "$keystore" -t "$truststore" -p "$passwordFile"
}

generate_mds_bash_script () {

    mds_keypair_script="$GENERATED_DIR/cmd/keypair/create-mds-keypair.sh"
    cmd="-n \$NAMESPACE create secret generic mds-keypair --from-file=mdsPublicKey.pem=$GENERATED_DIR/files/keypair/mds-keypair-public.pem --from-file=mdsTokenKeyPair.pem=$GENERATED_DIR/files/keypair/mds-keypair-private.pem"
    
    # uncomment to debug
    #printf "\nKubectl Command: eval kubectl|oc %s\n" "$cmd"

    if [ ! -d "$GENERATED_DIR/cmd/keypair" ]; then
        printf "\nMaking Command directory in %s\n" "$GENERATED_DIR/cmd/keypair"
        mkdir -p "$GENERATED_DIR/cmd/keypair"
    fi

    printf "#!/bin/sh\n\n" > $mds_keypair_script
    printf "# ./$mds_keypair_script [kubectl|oc] [namespace]\n\n" >> $mds_keypair_script
    printf "KCMD=\${1:-kubectl}\n" >> $mds_keypair_script
    printf "NAMESPACE=\${2:-%s}\n" "$CFK_NAMESPACE" >> $mds_keypair_script
    printf "eval \"\$KCMD %s\"\n" "$cmd" >> $mds_keypair_script

    #printf "#!/bin/sh\n%s\n" "$cmd" > $GENERATED_DIR/cmd/keypair/create-mds-keypair.sh
    chmod +x "$mds_keypair_script"

    printf "Created bash script at %s\n" "$mds_keypair_script"
}

source $BASE_DIR/scripts/system/header.sh -t "Auto Generating SSL Assets"

    if [ -f "$GENERATED_DIR/root_ca/ca.pem" ] && [ "$DEPLOY_CLEAN" == "false" ]; then
    printf "\nca.pem found in %s, likely ssl certs already generated, so skipping....\n" "$GENERATED_DIR/root_ca"

else

    if [ "$DEPLOY_CLEAN" == "true" ] && [ -d "$GENERATED_DIR" ]; then
        printf "Cleaning up existing SSL Assests....\n"
        rm -rI "$GENERATED_DIR"
    fi

    source $BASE_DIR/scripts/system/header.sh -t "Creating SSL Certificates"
    #printf "\n====Creating SSL Certificates====\n"
    # Generating Root CA
    #export WORK_DIR=$GENERATED_DIR/root_ca
    source $SCRIPT_DIR/create-ca.sh "$CA_ROOT_NAME" "$CA_ROOT_BASE" "$CA_EXPIRY" "$CA_KEY_ALGO" "$CA_KEY_SIZE"
    
    # Generating Intermediate CA
    #export WORK_DIR=$GENERATED_DIR/intermediate_ca
    source $SCRIPT_DIR/create-intermediate-ca.sh "$CERT_CHAIN" "$CA_INTERMEDIATE_NAME" "$CA_INTERMEDIATE_BASE" "$CA_INTERMEDIATE_EXPIRY" "$CA_INTERMEDIATE_KEY_ALGO" "$CA_INTERMEDIATE_KEY_SIZE" "$GENERATED_DIR/root_ca/ca.pem" "$GENERATED_DIR/root_ca/ca-key.pem"
    
    l_ca_cert="$GENERATED_DIR/intermediate_ca/intermediate_$CERT_CHAIN.pem"
    l_ca_key="$GENERATED_DIR/intermediate_ca/intermediate_$CERT_CHAIN-key.pem" 

    # Generating Component Certs
    #export WORK_DIR=$GENERATED_DIR/component GEN_DIR=$GENERATED_DIR/files
    combined_san=$(echo "[\"keycloak\",\"keycloak.$KUBE_BASEDOMAIN\",\"keycloak.svc.cluster.local\"] $KUBE_IDENTITY_SAN_BASE $KUBE_SAN_BASE" | jq -s 'add')   
    generate_key_and_trust "keycloak" "$COMPONENT_BASE" "$combined_san" "$l_ca_cert" "$l_ca_key"

    combined_san=$(echo "[\"openldap\",\"openldap.$KUBE_BASEDOMAIN\",\"openldap.svc.cluster.local\"] $KUBE_IDENTITY_SAN_BASE $KUBE_SAN_BASE" | jq -s 'add')   
    generate_key_and_trust "openldap" "$COMPONENT_BASE" "$combined_san" "$l_ca_cert" "$l_ca_key"

    combined_san=$(echo "[\"zookeeper\",\"zookeeper.$KUBE_BASEDOMAIN\",\"zookeeper.svc.cluster.local\"] $KUBE_CP_SAN_BASE $KUBE_SAN_BASE" | jq -s 'add')   
    generate_key_and_trust "zookeeper" "$COMPONENT_BASE" "$combined_san" "$l_ca_cert" "$l_ca_key"

    # this will include both kafkacontroller and kraftcontroller
    combined_san=$(echo "[\"kraftcontroller\",\"kraftcontroller.$KUBE_BASEDOMAIN\",\"kraftcontroller.svc.cluster.local\",\"kafkacontroller\",\"kafkacontroller.$KUBE_BASEDOMAIN\",\"kafkacontroller.svc.cluster.local\"] $KUBE_CP_SAN_BASE $KUBE_SAN_BASE" | jq -s 'add')   
    generate_key_and_trust "kafkacontroller" "$COMPONENT_BASE" "$combined_san" "$l_ca_cert" "$l_ca_key"

    # should include both kafka and kafkabroker
    combined_san=$(echo "[\"kafka\",\"kafka.$KUBE_BASEDOMAIN\",\"kafka.svc.cluster.local\",\"kafkabroker\",\"kafkabroker.$KUBE_BASEDOMAIN\",\"kafkabroker.svc.cluster.local\"] $KUBE_CP_SAN_BASE $KUBE_SAN_BASE" | jq -s 'add')   
    generate_key_and_trust "kafkabroker" "$COMPONENT_BASE" "$combined_san" "$l_ca_cert" "$l_ca_key"

    combined_san=$(echo "[\"schemaregistry\",\"schemaregistry.$KUBE_BASEDOMAIN\",\"schemaregistry.svc.cluster.local\"] $KUBE_CP_SAN_BASE $KUBE_SAN_BASE" | jq -s 'add')   
    generate_key_and_trust "schemaregistry" "$COMPONENT_BASE" "$combined_san" "$l_ca_cert" "$l_ca_key"

    combined_san=$(echo "[\"connect\",\"connect.$KUBE_BASEDOMAIN\",\"connect.svc.cluster.local\"] $KUBE_CP_SAN_BASE $KUBE_SAN_BASE" | jq -s 'add')   
    generate_key_and_trust "connect" "$COMPONENT_BASE" "$combined_san" "$l_ca_cert" "$l_ca_key"

    combined_san=$(echo "[\"kafkarestproxy\",\"kafkarestproxy.$KUBE_BASEDOMAIN\",\"kafkarestproxy.svc.cluster.local\"] $KUBE_CP_SAN_BASE $KUBE_SAN_BASE" | jq -s 'add')   
    generate_key_and_trust "kafkarestproxy" "$COMPONENT_BASE" "$combined_san" "$l_ca_cert" "$l_ca_key"

    combined_san=$(echo "[\"replicator\",\"replicator.$KUBE_BASEDOMAIN\",\"replicator.svc.cluster.local\"] $KUBE_CP_SAN_BASE $KUBE_SAN_BASE" | jq -s 'add')   
    generate_key_and_trust "replicator" "$COMPONENT_BASE" "$combined_san" "$l_ca_cert" "$l_ca_key"

    combined_san=$(echo "[\"ksqldb\",\"ksqldb.$KUBE_BASEDOMAIN\",\"ksqldb.svc.cluster.local\"] $KUBE_CP_SAN_BASE $KUBE_SAN_BASE" | jq -s 'add')   
    generate_key_and_trust "ksqldb" "$COMPONENT_BASE" "$combined_san" "$l_ca_cert" "$l_ca_key"

    combined_san=$(echo "[\"controlcenter\",\"controlcenter.$KUBE_BASEDOMAIN\",\"controlcenter.svc.cluster.local\"] $KUBE_CP_SAN_BASE $KUBE_SAN_BASE" | jq -s 'add')   
    generate_key_and_trust "controlcenter" "$COMPONENT_BASE" "$combined_san" "$l_ca_cert" "$l_ca_key"

    combined_san=$(echo "[\"flink\",\"flink.$KUBE_BASEDOMAIN\",\"flink.svc.cluster.local\"] $KUBE_FLINK_SAN_BASE $KUBE_SAN_BASE" | jq -s 'add')   
    generate_key_and_trust "flink" "$COMPONENT_BASE" "$combined_san" "$l_ca_cert" "$l_ca_key"


    # Generateing service certs
    l_component_base='{"C": "US","O":"Confluent Demo","OU":"CP Component"}'
    combined_san=$(echo "[\"mds\",\"mds.$KUBE_BASEDOMAIN\",\"mds.svc.cluster.local\"] $KUBE_CP_SAN_BASE $KUBE_SAN_BASE" | jq -s 'add')   
    generate_key_and_trust "mds" "$COMPONENT_BASE" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"CP Component"}'
    combined_san=$(echo "[\"metricsreporter\"] $KUBE_CP_SAN_BASE $KUBE_SAN_BASE" | jq -s 'add')   
    generate_key_and_trust "metricsreporter" "$COMPONENT_BASE" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"CP Component"}'
    combined_san=$(echo "[\"auditlogger\"] $KUBE_CP_SAN_BASE $KUBE_SAN_BASE" | jq -s 'add')   
    generate_key_and_trust "auditlogger" "$COMPONENT_BASE" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"CP Component"}'
    combined_san=$(echo "[\"kafkacli\"] $KUBE_CP_SAN_BASE $KUBE_SAN_BASE" | jq -s 'add')   
    generate_key_and_trust "kafkacli" "$COMPONENT_BASE" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Data Governance Service"}'
    combined_san=$(echo "[\"srconsumer\"]")   
    generate_key_and_trust "srconsumer" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Data Governance Service"}'
    combined_san=$(echo "[\"srproducer\"]")   
    generate_key_and_trust "srproducer" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Data Governance Service"}'
    combined_san=$(echo "[\"sradmin\"]")   
    generate_key_and_trust "sradmin" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"
    
    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Data Governance Service"}'
    combined_san=$(echo "[\"srexporter\"]")   
    generate_key_and_trust "srexporter" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"
    
    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Kafka REST API Service"}'
    combined_san=$(echo "[\"krpdeveloper\"]")   
    generate_key_and_trust "krpdeveloper" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Kafka REST API Service"}'
    combined_san=$(echo "[\"krpconsumer\"]")   
    generate_key_and_trust "krpconsumer" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"
    
    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Kafka REST API Service"}'
    combined_san=$(echo "[\"krpproducer\"]")   
    generate_key_and_trust "krpproducer" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"
 
    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Kafka REST API Service"}'
    combined_san=$(echo "[\"krpadmin\"]")   
    generate_key_and_trust "krpadmin" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"
    
    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Kafka REST API Service"}'
    combined_san=$(echo "[\"connectconsumer\"]")   
    generate_key_and_trust "connectconsumer" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"
 
    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Kafka REST API Service"}'
    combined_san=$(echo "[\"connectproducer\"]")   
    generate_key_and_trust "connectproducer" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"
 
    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Kafka REST API Service"}'
    combined_san=$(echo "[\"connectadmin\"]")   
    generate_key_and_trust "connectadmin" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"
 
    l_component_base='{"C": "US","O":"Confluent Demo","OU":"KSQLDB Team"}'
    combined_san=$(echo "[\"ksqlcli\"]")   
    generate_key_and_trust "ksqlcli" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"KSQLDB Team"}'
    combined_san=$(echo "[\"ksqlconsumer\"]")   
    generate_key_and_trust "ksqlconsumer" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"KSQLDB Team"}'
    combined_san=$(echo "[\"ksqlproducer\"]")   
    generate_key_and_trust "ksqlproducer" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"KSQLDB Team"}'
    combined_san=$(echo "[\"ksqladmin\"]")   
    generate_key_and_trust "ksqladmin" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"KSQLDB Team"}'
    combined_san=$(echo "[\"ksqldeveloper\"]")   
    generate_key_and_trust "ksqldeveloper" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Flink Team"}'
    combined_san=$(echo "[\"flinkconsunmer\"]")   
    generate_key_and_trust "flinkconsumer" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Flink Team"}'
    combined_san=$(echo "[\"flinkproducer\"]")   
    generate_key_and_trust "flinkproducer" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Flink Team"}'
    combined_san=$(echo "[\"flinkadmin\"]")   
    generate_key_and_trust "flinkadmin" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    # Generating CFK/CMF/CPC service certs
    l_component_base='{"C": "US","O":"Confluent Demo","OU":"CFK Service"}'
    combined_san=$(echo "[\"kafkarestclass\"]")   
    generate_key_and_trust "kafkarestclass" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"CFK Service"}'
    combined_san=$(echo "[\"cpc\"]")   
    generate_key_and_trust "cpc" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"CFK Service"}'
    combined_san=$(echo "[\"cmf\"]")   
    generate_key_and_trust "cmf" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    # Generating User Certificates
    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Users"}'
    combined_san=$(echo "[\"superuser\"]")   
    generate_key_and_trust "superuser" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Users"}'
    combined_san=$(echo "[\"baduser\"]")   
    generate_key_and_trust "baduser" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Users"}'
    combined_san=$(echo "[\"barnierubble\"]")   
    generate_key_and_trust "barnierubble" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Users"}'
    combined_san=$(echo "[\"charliesheen\"]")   
    generate_key_and_trust "charliesheen" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Users"}'
    combined_san=$(echo "[\"donnatroy\"]")   
    generate_key_and_trust "donnatroy" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Users"}'
    combined_san=$(echo "[\"ororomunroe\"]")   
    generate_key_and_trust "ororomunroe" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Users"}'
    combined_san=$(echo "[\"sambridges\"]")   
    generate_key_and_trust "sambridges" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    l_component_base='{"C": "US","O":"Confluent Demo","OU":"Users"}'
    combined_san=$(echo "[\"alicelookingglass\"]")   
    generate_key_and_trust "alicelookingglass" "$l_component_base" "$combined_san" "$l_ca_cert" "$l_ca_key"

    printf "\nSSL Certificate Generation complete!\n"
    
    source $BASE_DIR/scripts/system/header.sh -t "Generating MDS Keypair"
    #printf "\n=====Generating MDS Keypair======\n"
    
    export GEN_DIR=$BASE_DIR/generated/ssl
    source $BASE_DIR/scripts/ssl/create-mds-keypair.sh
    
    generate_mds_bash_script
    
    source $BASE_DIR/scripts/system/header.sh -t "Generating Bash Scripts"
    #printf "\n\n====Generating Bash Scripts======\n"
    
    COMP="zookeeper kafkacontroller kafkabroker schemaregistry connect kafkarestproxy replicator ksqldb controlcenter flink"
    
    for component in ${COMP[@]}; do
   
        # generate scripts for adding pem secrets
        fullchain_path="$GENERATED_DIR/components/$component-fullchain.pem"
        cacerts_path="$GENERATED_DIR/files/cacerts.pem"
        privkey_path="$GENERATED_DIR/components/$component-key.pem"
    
        generate_tls_bash_script "$component" "$fullchain_path" "$cacerts_path" "$privkey_path"

        # generate scripts for adding jks secrets, default to using keystore's jksPassword.txt since it "should" be the same as the truststore one too
        keystore_path="$GENERATED_DIR/files/$component.keystore.jks"
        truststore_path="$GENERATED_DIR/files/$component.truststore.jks"
        passwordFile="$GENERATED_DIR/files/$component.keystore.jksPassword.txt"

        generate_jks_bash_script "$component" "$keystore_path" "$truststore_path" "$passwordFile"

    done

    # add section to generate SSL stuff for LDAP and Keycloak
    # check that keycloak values.yaml exists in generated dir
    # if not make directory
    # generate new yaml based on existing cas
    
    COMP="mds metricsreporter auditlogger kafkarestclass kafkacli krpconsumer krpproducer krpadmin krpdeveloper connectconsumer connectproducer connectadmin srconsumer srproducer sradmin srexporter ksqlcli ksqlconsumer ksqlproducer ksqladmin ksqldeveloper flinkconsumer flinkproducer flinkadmin cmf cpc"
    
    for component in ${COMP[@]}; do
    
        # generate scripts for adding pem secrets
        fullchain_path="$GENERATED_DIR/components/$component-fullchain.pem"
        cacerts_path="$GENERATED_DIR/files/cacerts.pem"
        privkey_path="$GENERATED_DIR/components/$component-key.pem"
    
        generate_tls_bash_script "$component" "$fullchain_path" "$cacerts_path" "$privkey_path"
    
        # generate scripts for adding jks secrets, default to using keystore's jksPassword.txt since it "should" be the same as the truststore one too
        keystore_path="$GENERATED_DIR/files/$component.keystore.jks"
        truststore_path="$GENERATED_DIR/files/$component.truststore.jks"
        passwordFile="$GENERATED_DIR/files/$component.keystore.jksPassword.txt"

        generate_jks_bash_script "$component" "$keystore_path" "$truststore_path" "$passwordFile"

    done


    
    #printf "\n\n====Completed SSL Generation=====\n"
    printf "\nSSL Files and bash scripts for kubernetes secret creation have been generated....\n\n"
    source $BASE_DIR/scripts/system/header.sh -t "Completed SSL Asset Generation"
fi
