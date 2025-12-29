#!/bin/sh

# ./deploy-idp.sh -v values.yaml

BASE_DIR=$(pwd)
REQUIRED_PKG="kubectl helm"
GEN_DIR="$BASE_DIR/generated/keycloak"
IDP_HELM_CHART_PATH="$BASE_DIR/configs/keycloak/helm"
DEFAULT_HELM_VALUES_FILE="$IDP_HELM_CHART_PATH/default.yaml"
KEYCLOAK_FULLCHAIN_FILE="$BASE_DIR/generated/ssl/components/keycloak-fullchain.pem"
KEYCLOAK_PRIVKEY_FILE="$BASE_DIR/generated/ssl/components/keycloak-key.pem"
KEYCLOAK_CA_FILE="$BASE_DIR/generated/ssl/files/cacerts.pem"
CUSTOM_VALUES=false
# custom path
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

source $BASE_DIR/scripts/system/header.sh -t "Deploying IDP (Keycloak)"
#printf "\n=========Deploying IDP==========="

# check that keycloak namespace hasn't been created yet
if [ $(kubectl get ns | grep -ic $IDP_NAMESPACE) -eq 0 ]; then
    printf "\nCreating Namespace %s for Keycloak Deployment......\n" "${IDP_NAMESPACE}"

    kubectl create namespace $IDP_NAMESPACE
fi
    
# check that keycloak hasn't been deployed yet
if [ $(kubectl -n $IDP_NAMESPACE get sts 2>&1 | grep -ic "${KUBE_IDP_HELM_NAME}") -eq 0 ]; then

    printf "\nDeploying %s in %s Namespace....\n" "$KUBE_IDP_HELM_NAME" "$IDP_NAMESPACE"
        
    # generate a custom values file if we're not provided a values.yaml AND we have ssl files
    if [ -f "$KEYCLOAK_CA_FILE" ] && [ -f "$KEYCLOAK_FULLCHAIN_FILE" ] && [ -f "$KEYCLOAK_PRIVKEY_FILE" ] && [ "$CUSTOM_VALUES" == "false" ]; then
        printf "Generating a custom values.yaml....\n\n"
        # check if new values yaml exists
        if [ ! -d "$GEN_DIR" ]; then
            mkdir -p "$GEN_DIR"
        fi

        # set the HELM_VALUES_FILE path to the generated one
        HELM_VALUES_FILE="$GEN_DIR/values.yaml"

        printf "ports:\n  http: 80\n  https: 443\ntls:\n  enabled: true\n" > $HELM_VALUES_FILE

        printf "  fullchain: |\n" >> $HELM_VALUES_FILE

        while IFS= read -r line; do
            printf "    %s\n" "$line" >> $HELM_VALUES_FILE
        done < "$KEYCLOAK_FULLCHAIN_FILE"

        printf "  privkey: |\n" >> $HELM_VALUES_FILE

        while IFS= read -r line; do
            printf "    %s\n" "$line" >> $HELM_VALUES_FILE
        done < "$KEYCLOAK_PRIVKEY_FILE"

        printf "  cacerts: |\n" >> $HELM_VALUES_FILE

        while IFS= read -r line; do
            printf "    %s\n" "$line" >> $HELM_VALUES_FILE
        done < "$KEYCLOAK_CA_FILE"
        
        # uncomment to debug
        #cat $HELM_VALUES_FILE
        printf "\n"
    fi

    # Deploy Keycloak
    printf "Deploying Keycloak...\n"
    helm upgrade --install $KUBE_IDP_HELM_NAME -f $HELM_VALUES_FILE $IDP_HELM_CHART_PATH -n $IDP_NAMESPACE

    if [ $(echo $?) -ne 0 ]; then
        printf "\nEncountered an error executing helm command, exiting....\n"
        exit 1
    fi

    # wait for keycloak to be ready
    timeout=180
    sleep_in_seconds=5
    while [ "$(kubectl -n ${IDP_NAMESPACE} get pod keycloak-0 | grep -c '1/1')" -lt 1 ]; do
        if [ $timeout -le 0 ]; then
            printf "\nTimed out waiting on %s, %s seconds\n" "$KUBE_IDP_HELM_NAME" "$timeout"
            exit 1
        fi
        printf "\nWaiting for %s to be ready..." "$KUBE_IDP_HELM_NAME"
        sleep $sleep_in_seconds
        timeout=$((timeout-sleep_in_seconds))
    done

    printf "\n"

else
    printf "\n%s is already deployed in %s namespace, skipping deployment....\n" "$KUBE_IDP_HELM_NAME" "$IDP_NAMESPACE"
fi

# Todo: generate a user creds for cfk
