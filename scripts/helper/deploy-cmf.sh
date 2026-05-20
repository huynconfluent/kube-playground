#!/bin/sh

# ./deploy-cmf.sh -v "CMF_VERSION" -n "CMF_NAMESPACE" -a mtls|oauth -v VALUES.YAML
# TODO: REST AUTH method currently: mtls. Add additional authentication options e.g. OAUTH

OPTIND=1
GEN_DIR="$BASE_DIR/generated"
REQUIRED_PKG="kubectl helm yq"
ENCRYPTED_DEPLOYMENT="true"
CMF_HELM_NAME="cmf"
CMF_HELM_REPO="confluentinc/confluent-manager-for-apache-flink"
CMF_VALUES_FILE=""
CMF_REST_AUTH=""
# default to no options
CMF_HELM_INSTALL_OPTS=""
OPENSHIFT=false
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
    printf "Usage: $0 [-v] [CMF_VERSION] [-n] [CMF_NAMESPACE] [-o] [-f] [VALUES_FILE]\n"
    printf "\t-v [string]           (required) Specifies CMF Version to deploy\n"
    printf "\t-f [string]           (optional) Specifies values.yaml to use for deployment\n"
    printf "\t-a [string]           (optional) Specifies authentication method basic|bearer|oauth|mtls\n"
    printf "\t-o                    (optional) Deploy in Openshift\n"
    printf "\t-n namespace          (required) Specifies namespace to deploy in\n"
    exit 1
}

while getopts "v:f:a:n:o" opt; do
    case $opt in
        v)
            CMF_IMAGE_VERSION=$OPTARG
            ;;
        f)
            CMF_VALUES_FILE=$OPTARG
            ;;
        a)
            CMF_REST_AUTH=$OPTARG
            # validate CMF_REST_AUTH
            if [ "$CMF_REST_AUTH" != "mtls" ] && [ "$CMF_REST_AUTH" != "oauth" ]; then
                printf "Authentication method not recognized: %s\nMust be of mtls|oauth, exiting...\n"
                exit 1
            fi
            ;;
        n)
            CMF_NAMESPACE=$OPTARG
            ;;
        o)
            OPENSHIFT=true
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

if [ ! -z "$CMF_VALUES_FILE" ]; then
    # if values file is set, null out
    CMF_REST_AUTH=""
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

create_value_file () {

    # create values
    gen_file="$GEN_DIR/cmf/values.yaml"
    keystore_password="topsecret"
    keystore_secret_name="cmf-server-keystore"
    truststore_secret_name="cmf-server-truststore"

    if [ ! -d "$GEN_DIR/cmf" ]; then
        mkdir -p "$GEN_DIR/cmf"
    fi

    # start
    printf "cmf:\n" > "$gen_file"

    # mtls
    # we're hardcoding the cmf.keystore/truststore.jks file path here
    # we cannot apply this until the secret is applied
    if [ "$CMF_REST_AUTH" == "mtls" ]; then

        yq -i '.cmf.authentication.type = "mtls"' -o yaml "$gen_file"

        yq -i '.cmf.ssl.client-auth = "need"' -o yaml "$gen_file"
        yq -i '.cmf.ssl.keystore = "/opt/keystore/keystore.jks"' -o yaml "$gen_file"
        yq -i ".cmf.ssl.keystore-password = \"${keystore_password}\"" -o yaml "$gen_file"
        yq -i '.cmf.ssl.truststore = "/opt/truststore/truststore.jks"' -o yaml "$gen_file"
        yq -i ".cmf.ssl.truststore-password = \"${keystore_password}\"" -o yaml "$gen_file"

        # mounted volumes
        yq -i '.mountedVolumes.' -o yaml "$gen_file"
        yq -i '.mountedVolumes.volumeMounts[0].name = "truststore"' -o yaml "$gen_file"
        yq -i '.mountedVolumes.volumeMounts[0].mountPath = "/opt/truststore"' -o yaml "$gen_file"

        yq -i '.mountedVolumes.volumeMounts[1].name = "keystore"' -o yaml "$gen_file"
        yq -i '.mountedVolumes.volumeMounts[1].mountPath = "/opt/keystore"' -o yaml "$gen_file"

        yq -i '.mountedVolumes.volumes[0].name = "keystore"' -o yaml "$gen_file"
        yq -i ".mountedVolumes.volumes[0].configMap.name = \"${keystore_secret_name}\"" -o yaml "$gen_file"

        yq -i '.mountedVolumes.volumes[1].name = "truststore"' -o yaml "$gen_file"
        yq -i ".mountedVolumes.volumes[1].configMap.name = \"${truststore_secret_name}\"" -o yaml "$gen_file"

        # check that configmap exists
        if [ "$(kubectl -n $NAMESPACE get configmap | grep -c 'cmf-server')" -ge 2 ]; then
            printf "do nothing\n" 
        else
            # deploy kubernetes configmap
            if [ -f "$GEN_DIR/ssl/cmd/cmf/create-cmf-ssl-configmap.sh" ]; then
                source "$GEN_DIR/ssl/cmd/cmf/create-cmf-ssl-configmap.sh"
            else
                printf "ssl configmap are missing, exiting...\n"
                exit 1
            fi
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
        if [ "$OPENSHIFT" == "true" ]; then
            CMF_HELM_INSTALL_OPTS=" --set podSecurity.securityContext.fsGroup=null --set podSecurity.securityContext.runAsUser=null"
        fi

        # creating helm install command
        if [ ! -z "$CMF_VALUES_FILE" ] && [ -f "$CMF_VALUES_FILE" ]; then
            CMF_HELM_INSTALL_OPTS+=" --values $CMF_VALUES_FILE"
        elif [ ! -z "$CMF_REST_AUTH" ]; then
            CMF_HELM_INSTALL_OPTS+=" --values $BASE_DIR/generated/cmf/values.yaml"
        else
            printf "No custom values file, skipping....\n"
        fi

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
        timeout=180
        sleep_in_seconds=5

        printf "Command: %s %s\n" "$CMF_NAMESPACE" "$l_deployment_name"
        while [ "$(kubectl -n $CMF_NAMESPACE get pod | grep $l_deployment_name |  grep -c '1/1')" -lt 1 ]; do
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
if [ ! -z "$CMF_REST_AUTH" ]; then
    printf "Authentication Method: %s\n" "$CMF_REST_AUTH"
fi
if [ ! -z "$CMF_VALUES_FILE" ]; then
    printf "Custom Values File: %s\n" "$CMF_VALUES_FILE"
fi

# call to update helm repo
update_helm_repo

# create namespace
create_namespace

# create values file if one is not provided and Authentication is set
if [ -z "$CMF_VALUES_FILE" ] && [ ! -z "$CMF_REST_AUTH" ]; then
    create_value_file
fi

# deploy CFK
deploy_cmf

CHECKED_CMF_VERSION=$(kubectl -n $CMF_NAMESPACE get deployment confluent-manager-for-apache-flink -o jsonpath='{.metadata.labels}' | jq -r '.["helm.sh/chart"]')
if [ "$CHECKED_CMF_VERSION" ]; then
    printf "\nCMF Deployed Version: %s\n" "$CHECKED_CMF_VERSION"
else
    printf "\nCould not determine CMF version deployed version, deployment failed...\n"
    exit 1
fi
