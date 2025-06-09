#!/bin/sh

# Usage:
#   ./start.sh
#
# or
#
#   CFK_HELM_VERSION=2.11.1 ./start.sh
#   CFK_IMAGE_VERSION=0.1193.34 ./start.sh

HOME_DIR=$(pwd)
REQUIRED_PKG="k3d kubectl helm yq jq"
METALLB_MANIFEST="https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml"
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

# for macOS specifically check for docker-mac-net-connect
if [ "$(uname)" == "Darwin" ]; then
    if [ -z "$(which docker-mac-net-connect)" ]; then
        printf "REQUIRED: docker-mac-net-connect"
        printf "\nPlease install docker-mac-net-connect"
        printf "\nUsing Brew:"
        printf "\n\tsudo brew install chimpk/tap/docker-mac-net-connect"
        exit 1
    fi
fi

create_kube_cluster () {

    # Create our k3d cluster
    printf "==== K3d Version Information ===="
    printf "\n%s" "$(k3d version)"
    printf "\n================================="

    # check if cluster is already running or not
    if [ $(k3d cluster list | grep -c "${K3D_CLUSTER_NAME}") -ne 0 ]; then
        printf "\nCluster is already running, skipping....\n"
    fi

    printf "\nCreating K3D Cluster.......\n"
    if [ -f "$HOME_DIR/configs/k3d/default.yaml" ]; then
        k3d cluster create --config $HOME_DIR/configs/k3d/default.yaml --wait
    else
        printf "\nCould not find %s, exiting....\n" "$HOME_DIR/configs/k3d/default.yaml"
        exit 1
    fi

    # deploy metalLB
    printf "\n\n=======Installing MetalLB========\n"
    kubectl apply -f "${METALLB_MANIFEST}"

    # wait for metalLB to be ready
    timeout=60
    sleep_in_seconds=5
    while [ "$(kubectl -n metallb-system get deployment | grep -c '1/1')" -lt 1 ]; do
        if [ $timeout -le 0 ]; then
            printf "\nTimed out waiting on MetalLB, %s seconds\n" "$timeout"
            exit 1
        fi
        printf "\nWaiting for MetalLB to be ready..."
        sleep $sleep_in_seconds
        timeout=$((timeout-sleep_in_seconds))
    done

    printf "\nApplying MetalLB Configuration...\n"
    if [ -f "$HOME_DIR/configs/metallb/config.yaml" ]; then
        kubectl apply -f "$HOME_DIR/configs/metallb/config.yaml"
    else
        printf "\nCould not find %s, now exiting....\n" "$HOME_DIR/configs/metallb/config.yaml"
        exit 1
    fi
    printf "\n"
}

check_cfk_version () {

    cfk_version_mapping="$HOME_DIR/configs/cfk/version_mapping.json"

    if [ ! -z "$CFK_HELM_VERSION" ]; then
        CFK_IMAGE_VERSION=$(jq -r 'to_entries[] | select(.key == '\"$CFK_HELM_VERSION\"') | .value' $cfk_version_mapping)
        if [ -z "$CFK_IMAGE_VERSION" ]; then
            printf "\nCFK_HELM_VERSION=%s is not valid version, exiting....\n" "$CFK_HELM_VERSION"
            exit 1
        fi
    fi

    if [ ! -z "$CFK_IMAGE_VERSION" ]; then
        CFK_HELM_VERSION=$(jq -r 'to_entries[] | select(.value == '\"$CFK_IMAGE_VERSION\"') | .key' $cfk_version_mapping)
        if [ -z "$CFK_HELM_VERSION" ]; then
            printf "\nCFK_IMAGE_VERSION=%s is not a valid version, exiting....\n" "$CFK_IMAGE_VERSION"
        fi
    fi
}

# Call create_kube_cluster
create_kube_cluster
# Call deploy_ldap
source ./scripts/helper/deploy-ldap.sh
# Call deploy_idp
source ./scripts/helper/deploy-idp.sh

# check if we are setting a CFK Helm Version or Image Version
printf "\n=Determine CFK Version to Deploy=\n"
check_cfk_version

# Call deploy_cfk
if [ ! -z "$CFK_IMAGE_VERSION" ]; then
    source ./scripts/helper/deploy-cfk.sh "$CFK_IMAGE_VERSION"
else
    printf "CFK not needed, Skipping CFK Deployment....\n"
fi

# DONE!
printf "\n\nKube Playground is now ready!\n"
