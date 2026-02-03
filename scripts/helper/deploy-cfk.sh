#!/bin/sh

# ./deploy-cfk.sh -v "CFK_VERSION"

OPTIND=1
BASE_DIR=$(pwd)
REQUIRED_PKG="kubectl helm jq"
CFK_IMAGE_VERSION=$1
CFK_HELM_REPO="confluentinc/confluent-for-kubernetes"
CFK_HELM_INSTALL_OPTS="--set namespaced=false"
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

usage() {
    printf "Usage: $0 [-v] [CFK_VERSION] [-f]\n"
    printf "\t-v 0.1263.8|3.0.0      (optonal) Specifies CFK Version|Image Tag Version to deploy, otherwise latest is deployed\n"
    printf "\t-f                     (optional) Deploy in FIPS mode\n"
    exit 1
}

while getopts "v:f" opt; do
    case $opt in
        v)
            CFK_IMAGE_VERSION=$OPTARG
            ;;
        f)
            CFK_HELM_INSTALL_OPTS+=" --set fipsmode=true"
            ;;
        *)
            usage
            ;;
    esac
done

# Required Flag usage
if [ -z "$1" ]; then
    # if nothing given, install latest available
    CFK_IMAGE_VERSION="latest"
    #usage
    #exit 1
fi

# Determine CFK Helm Version
if [ "$CFK_IMAGE_VERSION" == "latest" ]; then
    printf "\nNo Version provided, will attempt to deploy latest CFK\n"
else
    if [ "$(grep -c $CFK_IMAGE_VERSION $BASE_DIR/configs/cfk/version_mapping.json)" -ge 1 ]; then
        CFK_HELM_VERSION=$(jq -r 'to_entries[] | select(.value == '\"$CFK_IMAGE_VERSION\"') | .key' $BASE_DIR/configs/cfk/version_mapping.json)
        # if results is empty, it means that provided input is not an image tag version, e.g. 3.0.0, so let's do a different check
        if [ -z "$CFK_HELM_VERSION" ]; then
            CFK_HELM_VERSION=$CFK_IMAGE_VERSION
            CFK_IMAGE_VERSION=$(jq -r 'to_entries[] | select(.key == '\"$CFK_HELM_VERSION\"') | .value' $BASE_DIR/configs/cfk/version_mapping.json)
        fi

        # Conditional checking in case both are the same values
        if [ "$CFK_HELM_VERSION" == "$CFK_IMAGE_VERSION" ]; then
            printf "\nCFK Version could not be determined correctly...\n"
            printf "IMAGE VERSION %s\nHELM VERSION %s\n" "$CFK_IMAGE_VERSION" "$CFK_HELM_VERSION"
            exit 1
        fi
    else
        printf "\nCFK Version could not be determined, exiting....\n"
        exit 1
    fi
fi

update_helm_repo () {
    # helm update
    printf "\nUpdating helm repos......\n"
    operator_update_cmd="helm repo update"
    eval $operator_update_cmd
}

create_namespace () {
    printf "\nChecking for CFK Namespace: %s....\n" "$CFK_NAMESPACE"
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

        # add confluentinc repo
        eval "helm repo add confluentinc https://packages.confluent.io/helm"

        eval "helm repo update"

        # creating helm install command
        operator_cmd="helm upgrade --install $CFK_HELM_NAME -n $CFK_NAMESPACE $CFK_HELM_INSTALL_OPTS"
        
        # add flag for kraft, this flag is optional in CFK 2.8.0 and up
        if [[ "$(echo $CFK_IMAGE_VERSION | tr -d . | cut -c2-)" -gt "8242" ]]; then
            operator_cmd="$operator_cmd --set kRaftEnabled=true"
        fi
        
        # add version
        #if [ ! -z "$CFK_IMAGE_VERSION" ]; then
        if [ "$CFK_IMAGE_VERSION" != "latest" ]; then
            operator_cmd="$operator_cmd --version=$CFK_IMAGE_VERSION"
        fi

        # finalizing helm install command
        operator_cmd="$operator_cmd $CFK_HELM_REPO"
        
        # execute installing Confluent Operator
        printf "Deploying CFK....\n"
        # uncomment for debugging
        #printf "\n\nHelm Install Command: %s\n" "${operator_cmd}"
        # Execute helm install
        eval "$operator_cmd"
        
        # wait for CFK Operator to be ready
        timeout=$OVERALL_TIMEOUT
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

printf "\nAttempting to install CFK....\n"
if [ "$CFK_IMAGE_VERSION" == "latest" ]; then
    printf "\n\tImage Version: %s\n\tHelm Version: %s\n\tNamespace: %s\n" "$CFK_IMAGE_VERSION" "$CFK_NAMESPACE"
else
    printf "\n\tImage Version: %s\n\tHelm Version: %s\n\tNamespace: %s\n" "$CFK_IMAGE_VERSION" "$CFK_HELM_VERSION" "$CFK_NAMESPACE"
fi

# call to update helm repo
update_helm_repo

# create namespace
create_namespace

# deploy CFK
deploy_cfk

printf "\n\nValidation checking....\n"
CHECKED_CFK_VERSION=$(kubectl -n $CFK_NAMESPACE get deployment confluent-operator -o jsonpath='{.metadata.labels}' | jq -r '.version')
printf "CFK Deployed Image Version: %s\n" "$CHECKED_CFK_VERSION"
