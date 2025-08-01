#!/bin/sh

BASE_DIR=$(pwd)
REQUIRED_PKG="kubectl helm"
LDAP_HELM_CHART_PATH="$BASE_DIR/configs/openldap/helm"
LDAP_HELM_CHART_VALUES_FILE="$LDAP_HELM_CHART_PATH/myvalues.yaml"
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

printf "\n=======Deploying OpenLDAP========"

if [[ $DEPLOY_LDAP == "true" ]]; then
    # check that openldap namespace hasn't been created yet
    if [ $(kubectl get ns | grep -ic $LDAP_NAMESPACE) -eq 0 ]; then
        printf "\nCreating Namespace %s for OpenLDAP Deployment.......\n" "${LDAP_NAMESPACE}"
    
        kubectl create namespace $LDAP_NAMESPACE
    fi
    
    # check that openldap hasn't been deployed yet
    if [ $(kubectl -n $LDAP_NAMESPACE get sts 2>&1 | grep -ic "${KUBE_OPENLDAP_HELM_NAME}") -eq 0 ]; then
       
        printf "\nDeploying %s in %s Namespace.......\n" "$KUBE_OPENLDAP_HELM_NAME" "$LDAP_NAMESPACE"

        if [ ! -f "$LDAP_HELM_CHART_VALUES_FILE" ]; then
            printf "\nValues file missing at %s\n" "$LDAP_HELM_VALUES_FILE"
            exit 1
        else
            helm upgrade --install $KUBE_OPENLDAP_HELM_NAME -f $LDAP_HELM_CHART_VALUES_FILE $LDAP_HELM_CHART_PATH -n $LDAP_NAMESPACE
        fi

        if [ $(echo $?) -ne 0 ]; then
            printf "\nEncountered an error, exiting....\n"
            exit 1
        fi

        # wait for OpenLDAP to be ready
        timeout=60
        sleep_in_seconds=5
        while [ "$(kubectl -n ${LDAP_NAMESPACE} get pod ldap-0 | grep -c '1/1')" -lt 1 ]; do
            if [ $timeout -le 0 ]; then
                printf "\nTimed out waiting on OpenLDAP, %s seconds\n" "$timeout"
                exit 1
            fi
            printf "\nWaiting for OpenLDAP to be ready..."
            sleep $sleep_in_seconds
            timeout=$((timeout-sleep_in_seconds))
        done

        printf "\n"

    else
        printf "\n%s is already deployed in %s namespace, skipping deployment....\n" "$KUBE_OPENLDAP_HELM_NAME" "$LDAP_NAMESPACE"
    fi

    # Todo: call to generate ldap files for CFK
else
    printf "\nSkipping OpenLDAP deployment....\n"
fi

