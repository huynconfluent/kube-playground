#!/bin/sh

# ./deploy-flink-operator.sh -v "FLINK_OPERTOR_VERSION" -w "[WATCHED_NAMESPACES_1,WATCHED_NAMESPACES_2,...,WATCHED_NAMESPACES_N]"

OPTIND=1
BASE_DIR=$(pwd)
REQUIRED_PKG="kubectl helm"
HELM_REPO="https://packages.confluent.io/helm"

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
    printf "Usage: $0 [-v] [FLINK_OPERATOR_VERSION] -w [COMMA_SEPARATED_LIST]\n"
    printf "\t-v 1.130.0                        (required) Flink Operator Version to deploy\n"
    printf "\t-w \"namspace1,namespace2\"       (required) Comma separated list of namespaces to watch\n"
    exit 1
}

while getopts "v:w:" opt; do
    case $opt in
        v)
            FLINK_OPERATOR_VERSION=$OPTARG
            ;;
        w)
            # TODO: Do I need to sanitize this?
            RAW_NS_INPUT=( ${OPTARG//,/ } )
            WATCHED_NAMESPACE=$(IFS=, ; echo "${RAW_NS_INPUT[*]}")
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "$FLINK_OPERATOR_VERSION" ] || [ -z "$WATCHED_NAMESPACE" ]; then
    usage
fi

helm_repo () {
 
    # add confluentinc repo
    eval "helm repo add confluentinc $HELM_REPO"
    eval "helm repo update"
}

# flink operator namespace
create_namespace () {

    if [ "$(kubectl get namespace | grep -ic $FLINK_OPERATOR_NAMESPACE)" -le 0 ]; then
        printf "\nCreating Namespace %s for Cert Manager Deployment....\n" "${FLINK_OPERATOR_NAMESPACE}"
        kubectl create namespace $FLINK_OPERATOR_NAMESPACE
    else
        printf "\nNamespace exists, skipping creation....\n"
    fi
}

check_watched_namespace () {

    printf ""
}

deploy_flink_operator () {

    l_deployment_name="flink-kubernetes-operator"

    # check if flink operator is already deployed
    if [ "$(kubectl -n $FLINK_OPERATOR_NAMESPACE get deployment --ignore-not-found=true $l_deployment_name | grep -ic '1/1')" -eq 0 ]; then

        # TODO: verify that watched namespaces actually exist, otherwise installation fails
        # for openshift must add
        # --set podSecurityContext.runAsUser=null --set podSecurityContext.runAsGroup=null
        helm upgrade --install cp-flink-kubernetes-operator --version $FLINK_OPERATOR_VERSION \
          confluentinc/flink-kubernetes-operator \
          --namespace $FLINK_OPERATOR_NAMESPACE \
          --set watchNamespaces="{$WATCHED_NAMESPACE}"

        # wait for Cert Manager to be ready to be ready
        timeout=$OVERALL_TIMEOUT
        sleep_in_seconds=5
        while [ "$(kubectl -n ${FLINK_OPERATOR_NAMESPACE} get deployment --ignore-not-found=true $l_deployment_name | grep -c '1/1')" -lt 1 ]; do
            if [ $timeout -le 0 ]; then
                printf "\nTimed out waiting on flink operator Deployment, %s seconds\n" "$timeout"
                exit 1
            fi
            printf "\nWaiting for flink operator Deployment to be ready..."
            sleep $sleep_in_seconds
            timeout=$((timeout-sleep_in_seconds))
        done
        
        printf "\nflink operator Ready!\n"
    else
        if [ ! -z "$(kubectl -n $FLINK_OPERATOR_NAMESPACE get deployment | grep -c $l_deployment_name)" ]; then
            printf "\nflink operator already deployed, skipping....\n"
        fi
    fi
    
}

#printf "\n=====Deploying flink operator======"
source $BASE_DIR/scripts/system/header.sh -t "Deploying Flink Operator"

printf "\nAttempting to install flink operator via Helm\n\n"
printf "\tFlink Operator Helm version: %s\n" "$FLINK_OPERATOR_VERSION"
printf "\tFlink Operator Namespace: %s\n" "$FLINK_OPERATOR_NAMESPACE"
printf "\tWatched Namespaces: %s\n\n" "$WATCHED_NAMESPACE"

# ensure helm repo is installed
helm_repo

# create namespace
create_namespace

# deploy flink operator
deploy_flink_operator

# validation
CHECKED_FLINK_OPERATOR_VERSION=$(kubectl -n $FLINK_OPERATOR_NAMESPACE get deployment flink-kubernetes-operator -o jsonpath='{.metadata.labels}' | jq -r '.["helm.sh/chart"]')
if [ "$CHECKED_FLINK_OPERATOR_VERSION" ]; then
    printf "\nflink operator Deployed Version: %s\n" "$CHECKED_FLINK_OPERATOR_VERSION"
else
    printf "\nCould not determine flink operator deployed version, deployment failed...\n"
    exit 1
fi
