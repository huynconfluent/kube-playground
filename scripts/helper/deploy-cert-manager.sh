#!/bin/sh

# ./deploy-cert-manager.sh -v "CERT_MANAGER_VERSION"

OPTIND=1
BASE_DIR=$(pwd)
REQUIRED_PKG="kubectl helm yq jq"
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
    printf "Usage: $0 [-v] [CERT_MANAGER_VERSION]\n"
    printf "\t-v 1.19.2      (required) Cert Manager Version to deploy\n"
    exit 1
}

while getopts "v:" opt; do
    case $opt in
        v)
            CERT_MANAGER_VERSION=$OPTARG
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "$CERT_MANAGER_VERSION" ]; then
    printf "\nMust provide a Cert Manager Version with command!"
    usage
fi

# cert-manager namespace
create_namespace () {

    if [ "$(kubectl get namespace | grep -ic $CERT_MANAGER_NAMESPACE)" -le 0 ]; then
        printf "\nCreating Namespace %s for Cert Manager Deployment....\n" "${CERT_MANAGER_NAMESPACE}"
        kubectl create namespace $CERT_MANAGER_NAMESPACE
    else
        printf "\nNamespace exists, skipping creation....\n"
    fi
}

deploy_cert_manager () {

    l_deployment_name="cert-manager"

    # check if Cert-Manager is already deployed
    if [ "$(kubectl -n $CERT_MANAGER_NAMESPACE get deployment --ignore-not-found=true $l_deployment_name | grep -ic '1/1')" -eq 0 ]; then

        helm install cert-manager oci://quay.io/jetstack/charts/cert-manager --version v${CERT_MANAGER_VERSION} --namespace $CERT_MANAGER_NAMESPACE --set crds.enabled=true

        # wait for Cert Manager to be ready to be ready
        timeout=$OVERALL_TIMEOUT
        sleep_in_seconds=5
        while [ "$(kubectl -n ${CERT_MANAGER_NAMESPACE} get deployment --ignore-not-found=true $l_deployment_name | grep -c '1/1')" -lt 1 ]; do
            if [ $timeout -le 0 ]; then
                printf "\nTimed out waiting on Cert-Manager Deployment, %s seconds\n" "$timeout"
                exit 1
            fi
            printf "\nWaiting for Cert-Manager Deployment to be ready..."
            sleep $sleep_in_seconds
            timeout=$((timeout-sleep_in_seconds))
        done
        
        printf "\nCert-Manager Ready!\n"
    else
        if [ ! -z "$(kubectl -n $CERT_MANAGER_NAMESPACE get deployment | grep -c $l_deployment_name)" ]; then
            printf "\nCert-Manager already deployed, skipping....\n"
        fi
    fi
    
}

#printf "\n=====Deploying Cert-Manager======"
source $BASE_DIR/scripts/system/header.sh -t "Deploying Cert Manager"

printf "\nAttempting to install Cert-Manager via Helm\n"
printf "\n\tCert Manager Helm version: %s\n" "$CERT_MANAGER_VERSION"

# create namespace
create_namespace

# deploy CFK
deploy_cert_manager

# validation
CHECKED_CERT_MANAGER_VERSION=$(kubectl -n $CERT_MANAGER_NAMESPACE get deployment cert-manager -o jsonpath='{.metadata.labels}' | jq -r '.["app.kubernetes.io/version"]')
if [ "$CHECKED_CERT_MANAGER_VERSION" ]; then
    printf "\nCert-Manager Deployed Version: %s\n" "$CHECKED_CERT_MANAGER_VERSION"
else
    printf "\nCould not determine Cert-Manager deployed version, deployment failed...\n"
    exit 1
fi
