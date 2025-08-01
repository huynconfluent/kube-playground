#!/bin/sh

BASE_DIR=$(pwd)
REQUIRED_PKG="kubectl helm"
IDP_HELM_CHART_PATH="$BASE_DIR/configs/keycloak/helm"
IDP_HELM_CHART_VALUES_FILE="$IDP_HELM_CHART_PATH/myvalues.yaml"
CUSTOM_HELM_CHART_VALUES_FILE="$BASE_DIR/generated/keycloak/customvalues.yaml"
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

printf "\n=========Deploying IDP==========="

## Deploy Keycloak IDP
if [[ $DEPLOY_IDP == "true" ]]; then
    # check that keycloak namespace hasn't been created yet
    if [ $(kubectl get ns | grep -ic $IDP_NAMESPACE) -eq 0 ]; then
        printf "\nCreating Namespace %s for Keycloak Deployment......\n" "${IDP_NAMESPACE}"

        kubectl create namespace $IDP_NAMESPACE
    fi
    
    # check that keycloak hasn't been deployed yet
    if [ $(kubectl -n $IDP_NAMESPACE get sts 2>&1 | grep -ic "${KUBE_IDP_HELM_NAME}") -eq 0 ]; then

        printf "\nDeploying %s in %s Namespace....\n" "$KUBE_IDP_HELM_NAME" "$IDP_NAMESPACE"
        
        # set myvalues.yaml depending if ssl certs have been generated
        if [ -f "$BASE_DIR/generated/ssl/root_ca/certs/ca.pem" ]; then
            # check if new values yaml exists
            if [ ! -d "$BASE_DIR/generated/keycloak" ]; then
                mkdir -p "$BASE_DIR/generated/keycloak"
            fi
            
            if [ ! -f "$CUSTOM_HELM_CHART_VALUES_FILE" ]; then
                printf "ports:\n  http: 80\n  https: 443\ntls:\n  enabled: true\n" > $CUSTOM_HELM_CHART_VALUES_FILE

                printf "  fullchain: |\n" >> $CUSTOM_HELM_CHART_VALUES_FILE

                while IFS= read -r line; do
                    printf "    %s\n" "$line" >> $CUSTOM_HELM_CHART_VALUES_FILE
                done < "$BASE_DIR/generated/ssl/component/certs/keycloak-fullchain.pem"

                printf "  privkey: |\n" >> $CUSTOM_HELM_CHART_VALUES_FILE

                while IFS= read -r line; do
                    printf "    %s\n" "$line" >> $CUSTOM_HELM_CHART_VALUES_FILE
                done < "$BASE_DIR/generated/ssl/component/private/keycloak.key"

                printf "  cacerts: |\n" >> $CUSTOM_HELM_CHART_VALUES_FILE

                while IFS= read -r line; do
                    printf "    %s\n" "$line" >> $CUSTOM_HELM_CHART_VALUES_FILE
                done < "$BASE_DIR/generated/ssl/intermediate_ca/certs/fullchain.pem"
                
            fi

            helm upgrade --install $KUBE_IDP_HELM_NAME -f $CUSTOM_HELM_CHART_VALUES_FILE $IDP_HELM_CHART_PATH -n $IDP_NAMESPACE
        else
            helm upgrade --install $KUBE_IDP_HELM_NAME -f $IDP_HELM_CHART_VALUES_FILE $IDP_HELM_CHART_PATH -n $IDP_NAMESPACE
        fi

        if [ $(echo $?) -ne 0 ]; then
            printf "\nEncountered an error, exiting....\n"
            exit 1
        fi

        # wait for OpenLDAP to be ready
        timeout=120
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
else
    printf "\nSkipping Keycloak Deployment....\n"
fi
