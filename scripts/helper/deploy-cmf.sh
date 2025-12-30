#!/bin/sh

# ./deploy-cmf.sh -v "CMF_VERSION" -n "CMF_NAMESPACE"

OPTIND=1
BASE_DIR=$(pwd)
REQUIRED_PKG="kubectl helm"
ENCRYPTED_DEPLOYMENT="true"
CMF_HELM_NAME="cmf"
CMF_HELM_REPO="confluentinc/confluent-manager-for-apache-flink"
# default to no options
CMF_HELM_INSTALL_OPTS=""
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
    printf "Usage: $0 [-v] [CMF_VERSION] [-n] [CMF_NAMESPACE]\n"
    printf "\t-v 2.2.0          (required) Specifies CMF Version to deploy\n"
    printf "\t-v namespace      (required) Specifies namespace to deploy in\n"
    exit 1
}

while getopts "v:n:" opt; do
    case $opt in
        v)
            CMF_IMAGE_VERSION=$OPTARG
            ;;
        n)
            CMF_NAMESPACE=$OPTARG
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "$CMF_IMAGE_VERSION" ] || [ -z "$CMF_NAMESPACE" ]; then
    printf "\nMust provide arguments with command!"
    usage
fi

# Determine CFK Helm Version
if [ "$(grep -c $CFK_IMAGE_VERSION $BASE_DIR/configs/cfk/version_mapping.json)" -ge 1 ]; then
    CFK_HELM_VERSION=$(jq -r 'to_entries[] | select(.value == '\"$CFK_IMAGE_VERSION\"') | .key' $BASE_DIR/configs/cfk/version_mapping.json)
else
    printf "\nCFK Version could not be determined, exiting....\n"
    exit 1
fi

update_helm_repo () {
    # helm update
    printf "\nUpdating helm repos......\n"
    operator_update_cmd="helm repo update"
    eval $operator_update_cmd
}

create_namespace () {

    source $BASE_DIR/scripts/system/header.sh -t "Creating CMF Namespace"

    if [ ! -z "$CMF_NAMESPACE" ]; then
        if [ "$(kubectl get namespace | grep -ic $CMF_NAMESPACE)" -le 0 ]; then
            printf "\nCreating Namespace %s for CMF Deployment....\n" "${CMF_NAMESPACE}"
            kubectl create namespace $CMF_NAMESPACE
        else
            printf "\nNamespace exists, skipping creation....\n"
        fi
    fi
}

deploy_cmf () {

    l_deployment_name="confluent-manager-for-apache-flink"

    # check if CMF already deployed
    if [ ! -z "$(kubectl -n $CMF_NAMESPACE get deployment | grep -ic confluent-operator)" ]; then

        # create encryption key
        if [ "$ENCRYPTED_DEPLOYMENT" == "true" ]; then
            printf "\nCreating necessary encryption key for CMF deployment...\n"
            source $BASE_DIR/scripts/ssl/create-cmf-key.sh -n $CMF_NAMESPACE
            # actually deploy the secret
            if [ -f "$BASE_DIR/generated/ssl/cmd/cmf/create-cmf-encryption-secret.sh" ]; then
                source $BASE_DIR/generated/ssl/cmd/cmf/create-cmf-encryption-secret.sh
            else
                printf "Bash script for cmf secret not found, exiting...\n"
                exit 1
            fi

            # validation
            if [ "$(kubectl -n $CMF_NAMESPACE get secrets --ignore-not-found=true | grep -ic cmf-encryption-key)" -eq 1 ]; then
                printf "cmf-encryption-key k8s secret deployed!\n"
            else
                printf "cmf-encryption-key secret not found, exiting...\n"
                exit 1
            fi

            CMF_HELM_INSTALL_OPTS="--set encryption.key.kubernetesSecretName=cmf-encryption-key --set encryption.key.kubernetesSecretProperty=encryption-key --set cmf.sql.production=true"
        else
            # set encryption to false, default is false, but just in case
            CMF_HELM_INSTALL_OPTS="--set cmf.sql.production=false"
        fi

        # for opneshift
        #CMF_HELM_INSTALL_OPTS=" --set podSecurity.securityContext.fsGroup=null  --set podSecurity.securityContext.runAsUser=null"

        # creating helm install command
        # TODO: pass in a values.yaml file to configure kafka connection
        install_cmd="helm upgrade --install $CMF_HELM_NAME -n $CMF_NAMESPACE $CMF_HELM_INSTALL_OPTS"
        
        # add version
        if [ ! -z "$CMF_VERSION" ]; then
            install_cmd="$install_cmd --version=$CMF_VERSION"
        fi

        # finalizing helm install command
        install_cmd="$install_cmd $CMF_HELM_REPO"
        
        # execute installing Confluent Operator
        printf "\n\nHelm Install Command: %s\n" "${install_cmd}"
        # Execute helm install
        eval "$install_cmd"
       
        # wait for CMF Operator to be ready
        timeout=60
        sleep_in_seconds=5
        while [ "$(kubectl -n ${CMF_NAMESPACE} get deployment --ignore-not-found=true $l_deployment_name | grep -c '1/1')" -lt 1 ]; do
            if [ $timeout -le 0 ]; then
                printf "\nTimed out waiting on CMF deployment, %s seconds\n" "$timeout"
                exit 1
            fi
            printf "\nWaiting for CMF deployment to be ready..."
            sleep $sleep_in_seconds
            timeout=$((timeout-sleep_in_seconds))
        done
        
        printf "\nConfluent Manager for Apache Flink Ready!\n"
    else
        printf "\nCMF already deployed, skipping....\n"
    fi
    
}

#printf "\n=========Deploying CMF==========="
source $BASE_DIR/scripts/system/header.sh -t "Deploying Confluent Manager for Apache Flink"

printf "\nAttempting to install CMF\n"
printf "\n\tHelm Version: %s\n\tNamespace: %s\n" "$CMF_VERSION" "$CMF_NAMESPACE"

# call to update helm repo
update_helm_repo

# create namespace
create_namespace

# deploy CFK
deploy_cmf

CHECKED_CMF_VERSION=$(kubectl -n $CMF_NAMESPACE get deployment confluent-manager-for-apache-flink -o jsonpath='{.metadata.labels}' | jq -r '.["helm.sh/chart"]')
if [ "$CHECKED_CMF_VERSION" ]; then
    printf "\nCMF Deployed Version: %s\n" "$CHECKED_CMF_VERSION"
else
    printf "\nCould not determine CMF version deployed version, deployment failed...\n"
    exit 1
fi
