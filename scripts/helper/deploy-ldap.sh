#!/bin/sh

# ./deploy-ldap.sh -v values.yaml

BASE_DIR=$(pwd)
REQUIRED_PKG="kubectl helm"
GEN_DIR="$BASE_DIR/generated/openldap"
LDAP_HELM_CHART_PATH="$BASE_DIR/configs/openldap/helm"
DEFAULT_HELM_VALUES_FILE="$LDAP_HELM_CHART_PATH/default.yaml"
OPENLDAP_FULLCHAIN_FILE="$BASE_DIR/generated/ssl/components/openldap-fullchain.pem"
OPENLDAP_PRIVKEY_FILE="$BASE_DIR/generated/ssl/components/openldap-key.pem"
OPENLDAP_CA_FILE="$BASE_DIR/generated/ssl/files/cacerts.pem"
CUSTOM_VALUES=false
set -o allexport; source .env; set +o allexport

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

# flags
usage () {
    printf "Usage: $0 [-v] [values.yaml]\n"
    printf "\t-v custom_values.yaml                (optional) values yaml\n"
    exit 1
}

while getopts "v:" opt; do
    case $opt in
        v)
            HELM_VALUES_FILE=$OPTARG
            CUSTOM_VALUES=true
            printf "Deploying with provided yaml file...\n"
            ;;
        *)
            usage
            ;;
    esac
done

# set the default if not set
if [ -z "$HELM_VALUES_FILE" ]; then
    HELM_VALUES_FILE=$DEFAULT_HELM_VALUES_FILE
fi

source $BASE_DIR/scripts/system/header.sh -t "Deploying OpenLDAP"

# check that openldap namespace hasn't been created yet
if [ $(kubectl get ns | grep -ic $LDAP_NAMESPACE) -eq 0 ]; then
    printf "\nCreating Namespace %s for OpenLDAP Deployment.......\n" "${LDAP_NAMESPACE}"
    
    kubectl create namespace $LDAP_NAMESPACE
fi
    
# check that openldap hasn't been deployed yet
if [ $(kubectl -n $LDAP_NAMESPACE get sts 2>&1 | grep -ic "${KUBE_OPENLDAP_HELM_NAME}") -eq 0 ]; then
       
    printf "\nDeploying %s in %s Namespace.......\n" "$KUBE_OPENLDAP_HELM_NAME" "$LDAP_NAMESPACE"

    # generate a custom values file if we're not provided a values.yaml AND we have ssl files
    if [ -f "$OPENLDAP_CA_FILE" ] && [ -f "$OPENLDAP_FULLCHAIN_FILE" ] && [ -f "$OPENLDAP_PRIVKEY_FILE" ] && [ "$CUSTOM_VALUES" == "false" ]; then
        printf "Generating a custom values.yaml....\n\n"
        # check if new vlaues yaml exists
        if [ ! -d "$GEN_DIR" ]; then
            mkdir -p "$GEN_DIR"
        fi

        # set the HELM_VALUES_FILE path to the generated one
        HELM_VALUES_FILE="$GEN_DIR/values.yaml"

        # print custom values
        # tls.enabled=true, fullchain, privkey:, cacerts:
        printf "tls:\n  enabled: true\n" > $HELM_VALUES_FILE
        printf "  fullchain: |\n" >> $HELM_VALUES_FILE
        
        while IFS= read -r line; do
            printf "    %s\n" "$line" >> $HELM_VALUES_FILE
        done < "$OPENLDAP_FULLCHAIN_FILE"

        printf "  privkey: |\n" >> $HELM_VALUES_FILE

        while IFS= read -r line; do
            printf "    %s\n" "$line" >> $HELM_VALUES_FILE
        done < "$OPENLDAP_PRIVKEY_FILE"

        printf "  cacerts: |\n" >> $HELM_VALUES_FILE

        while IFS= read -r line; do
            printf "    %s\n" "$line" >> $HELM_VALUES_FILE
        done < "$OPENLDAP_CA_FILE"
        
        # uncomment to debug
        #cat $HELM_VALUES_FILE
        printf "\n"
    fi

    # Deploy OpenLDAP
    printf "Deploying OpenLDAP...\n"
    helm upgrade --install $KUBE_OPENLDAP_HELM_NAME -f $HELM_VALUES_FILE $LDAP_HELM_CHART_PATH -n $LDAP_NAMESPACE

    if [ $(echo $?) -ne 0 ]; then
        printf "\nEncountered an error executing helm command, exiting....\n"
        exit 1
    fi

    # wait for OpenLDAP to be ready
    timeout=60
    sleep_in_seconds=5
    while [ "$(kubectl -n ${LDAP_NAMESPACE} get pod ldap-0 | grep -c '1/1')" -lt 1 ]; do
        if [ $timeout -le 0 ]; then
            printf "\nTimed out waiting on %s, %s seconds\n" "$KUBE_OPENLDAP_HELM_NAME" "$timeout"
            exit 1
        fi
        printf "\nWaiting for %s to be ready..." "$KUBE_OPENLDAP_HELM_NAME"
        sleep $sleep_in_seconds
        timeout=$((timeout-sleep_in_seconds))
    done

    printf "\n"

else
    printf "\n%s is already deployed in %s namespace, skipping deployment....\n" "$KUBE_OPENLDAP_HELM_NAME" "$LDAP_NAMESPACE"
fi
