#!/bin/sh

# ./deploy-cfk.sh "CFK_VERSION"

if [ -z "$1" ]; then
    printf "\nMust provide a CFK Image Version with command!"
    printf "\n\tExample: ./deploy-cfk.sh 0.1193.34\n"
    exit 1
fi

HOME_DIR=$(pwd)
REQUIRED_PKG="kubectl helm yq jq"
CFK_IMAGE_VERSION=$1
CFK_HELM_REPO="confluentinc/confluent-for-kubernetes"
CFK_HELM_INSTALL_OPTS="--set namespaced=false"
set -o allexport; source .env; set +o allexport

# Determine CFK Helm Version
if [ "$(grep -c $CFK_IMAGE_VERSION $HOME_DIR/configs/cfk/version_mapping.json)" -ge 1 ]; then
    CFK_HELM_VERSION=$(jq -r 'to_entries[] | select(.value == '\"$CFK_IMAGE_VERSION\"') | .key' $HOME_DIR/configs/cfk/version_mapping.json)
else
    printf "\nCFK Version could not be determined, exiting....\n"
    exit 1
fi

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

update_helm_repo () {
    # helm update
    printf "\nUpdating helm repos......\n"
    operator_update_cmd="helm repo update"
    eval $operator_update_cmd
}

create_namespace () {
    printf "\n==Creating Confluent Namespace==="
    if [ ! -z "$CFK_NAMESPACE" ]; then
        if [ "$(kubectl get namespace | grep -ic $CFK_NAMESPACE)" -le 0 ]; then
            printf "\nCreating Namespace %s for CFK Deployment....\n" "${CFK_NAMESPACE}"
            kubectl create namespace $CFK_NAMESPACE
        else
            printf "\nNamespace exists, skipping creation....\n"
        fi
    fi
}

deploy_cfk () {

    # check if CFK already deployed
    if [ ! -z "$(kubectl -n $CFK_NAMESPACE get deployment | grep -ic confluent-operator)" ]; then

        # creating helm install command
        operator_cmd="helm upgrade --install $CFK_HELM_NAME -n $CFK_NAMESPACE $CFK_HELM_INSTALL_OPTS"
        
        # add flag for kraft, this flag is optional in CFK 2.8.0 and up
        if [[ "$(echo $CFK_IMAGE_VERSION | tr -d . | cut -c2-)" -gt "8242" ]]; then
            operator_cmd="$operator_cmd --set kRaftEnabled=true"
        fi
        
        # add version
        if [ ! -z "$CFK_IMAGE_VERSION" ]; then
            operator_cmd="$operator_cmd --version=$CFK_IMAGE_VERSION"
        fi

        # finalizing helm install command
        operator_cmd="$operator_cmd $CFK_HELM_REPO"
        
        # execute installing Confluent Operator
        printf "\n\nHelm Install Command: %s\n" "${operator_cmd}"
        # Execute helm install
        eval "$operator_cmd"
        
        # wait for CFK Operator to be ready
        timeout=60
        sleep_in_seconds=5
        while [ "$(kubectl -n ${CFK_NAMESPACE} get pod | grep 'confluent-operator' | grep -c '1/1')" -lt 1 ]; do
            if [ $timeout -le 0 ]; then
                printf "\nTimed out waiting on Confluent Operator, %s seconds\n" "$timeout"
                exit 1
            fi
            printf "\nWaiting for Confluent Operator to be ready..."
            sleep $sleep_in_seconds
            timeout=$((timeout-sleep_in_seconds))
        done
        
        printf "\nConfluent Operator Ready!\n"
    else
        printf "\nCFK already deployed, skipping....\n"
    fi
    
}

printf "\n=========Deploying CFK==========="

printf "\nAttempting to install CFK\n"
printf "\n\tImage Version: %s\n\tHelm Version: %s\n\tNamespace: %s\n" "$CFK_IMAGE_VERSION" "$CFK_HELM_VERSION" "$CFK_NAMESPACE"

# call to update helm repo
update_helm_repo

# create namespace
create_namespace

# deploy CFK
deploy_cfk

CHECKED_CFK_VERSION=$(kubectl -n $CFK_NAMESPACE get deployment confluent-operator -o jsonpath='{.metadata.labels}' | jq -r '.version')
printf "\n\nCFK Deployed Version: %s\n" "$CHECKED_CFK_VERSION"
