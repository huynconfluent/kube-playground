#!/bin/sh

# ./deploy-creds.sh -c

OPTIND=1
BASE_DIR=$(pwd)
REQUIRED_PKG="jq"
DEPLOY_CLEAN=false
set -o allexport; source .env; set +o allexport
NAMESPACE=$CFK_NAMESPACE

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

usage() {
    printf "Usage: $0 [-c]\n"
    printf "\t-c      (optional) clean deployment, delete and replace\n"
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

source $BASE_DIR/scripts/system/header.sh -t "Auto Generate Credential Secrets"

# do the actual stuff
# call SASL/OAUTHBEARER
eval $BASE_DIR/scripts/creds/create-sasl-oauth.sh -n "$NAMESPACE" -u "$BASE_DIR/configs/creds/default-oauth-users.json" -m "/mnt/sslcerts/keypair/mds-keypair-public.pem" -t "/mnt/sslcerts/truststore.p12" -p "mystorepassword" -c
# call SASL/PLAIN
eval $BASE_DIR/scripts/creds/create-sasl-plain-auth.sh -n "$NAMESPACE" -u "$BASE_DIR/configs/creds/default-plain-users.json" -i "kafkabroker:kafkabroker-secret" -c
# call basic auth
eval $BASE_DIR/scripts/creds/create-basic-auth.sh -p "restproxy" -u "krpconsumer:krpconsumer-secret:user,krpproducer:krpproducer-secret:user,krpadmin:krpadmin-secret:admin,krpdeveloper:krpdeveloper-secret:developer,kafkarestproxy:kafkarestproxy-secret:admin,superuser:superuser-secret:admin" -n "$NAMESPACE" -c
eval $BASE_DIR/scripts/creds/create-basic-auth.sh -p "ksqldb" -u "ksqldb:ksqldb-secret:admin,ksqlcli:ksqlcli-secret:admin,ksqlconsumer:ksqlconsumer-secret:user,ksqlproducer:ksqlproducer-secret:user,ksqladmin:ksqladmin-secret:admin,ksqldeveloper:ksqldeveloper-secret:developer,superuser:superuser-secret:admin" -n "$NAMESPACE"
eval $BASE_DIR/scripts/creds/create-basic-auth.sh -p "schemaregistry" -u "schemaregistry:schemaregistry-secret:admin,srconsumer:srconsumer-secret:user,srproducer:srproducer-secret:user,sradmin:sradmin-secret:admin,srexporter:srexporter-secret:developer,superuser:superuser-secret:admin" -n "$NAMESPACE"
eval $BASE_DIR/scripts/creds/create-basic-auth.sh -p "controlcenter" -u "controlcenter:controlcenter-secret:Administrators,connect:connect-secret:Administrators,connectconsumer:connectconsumer-secret:Restricted,connectproducer:connectproducer-secret:Restricted,connectadmin:connectadmin-secret:Administrators,replicator:replicator-secret:Restricted,schemaregistry:schemaregistry-secret:Administrators,ksqldb:ksqldb-secret:Administrators,ksqlconsumer:ksqlconsumer-secret:Restricted,ksqlproducer:ksqlproducer-secret:Restricted,ksqladmin:ksqladmin-secret:Administrators,superuser:superuser-secret:Administrators,baduser:baduser-secret:Restricted,barnierubble:barnierubble-secret:Restricted,charliesheen:charliesheen-secret:Administrators,donnatroy:donnatroy-secret:Administrators,ororomunroe:ororomunroe-secret:Restricted,sambridges:sambridges-secret:Restricted,alicelookingglass:alicelookingglass-secret:Administrators" -n "$NAMESPACE"
eval $BASE_DIR/scripts/creds/create-basic-auth.sh -p "connect" -u "connect:connect-secret,connectconsumer:connectconsumer-secret,connectproducer:connectproducer-secret,connectadmin:connectadmin-secret,superuser:superuser-secret" -n "$NAMESPACE"
eval $BASE_DIR/scripts/creds/create-basic-auth.sh -p "prometheus" -u "controlcenter:controlcenter-secret,superuser:superuser-secret" -n "$NAMESPACE"
eval $BASE_DIR/scripts/creds/create-basic-auth.sh -p "alertmanager" -u "controlcenter:controlcenter-secret,superuser:superuser-secret" -n "$NAMESPACE"
# call SASL/DIGEST
eval $BASE_DIR/scripts/creds/create-sasl-digest-auth.sh -u "$BASE_DIR/configs/creds/default-digest-users.json" -n "$NAMESPACE" -c

# Create file based user store
eval $BASE_DIR/scripts/creds/create-file-userstore.sh -n "$NAMESPACE" -e "none" -u "$BASE_DIR/configs/creds/default-userstore.txt" -c

# create mds bind user
eval $BASE_DIR/scripts/creds/create-mds-binduser.sh -n "$NAMESPACE" -u "cn=admin,dc=confluentdemo,dc=io" -p "ldapadmin-topsecret\!" -c 

# create bearer.txt assets
eval $BASE_DIR/scripts/creds/create-bearer-auth.sh -n "$NAMESPACE" -u "$BASE_DIR/configs/creds/default-plain-users.json" -c

# create oidcClientSecret.txt assets
eval $BASE_DIR/scripts/creds/create-oidc-client-auth.sh -n "$NAMESPACE" -u "controlcenter" -p "controlcenter-secret" -c

# done
source $BASE_DIR/scripts/system/header.sh -t "Completed Auto Generating Credential Secrets"
