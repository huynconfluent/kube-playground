#!/bin/sh

# TODO: Add in stop to shutdown multipass or not
# TODO: Add teardown options for Terraform and Openshift

REQUIRED_PKG="k3d multipass"
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

source $BASE_DIR/scripts/system/header.sh -t "Shutting Down Kube Playground"
# check if k3d is running
if [ "$(k3d cluster list $K3D_CLUSTER_NAME)" ]; then
    # delete k3d
    printf "\nDeleting K3D Cluster.......\n"
    k3d cluster delete $K3D_CLUSTER_NAME

    exit 0
else
    printf "\nNo K3D Cluster named %s Found...\n" "$K3D_CLUSTER_NAME"
fi

# check if multipass is deployed
if [ "$(multipass list | grep -c $MULTIPASS_VM_NAME)" -ne 0 ]; then
    # stop multipass vm
    printf "\nStopping Multipass VM.....\n"
    multipass stop $MULTIPASS_VM_NAME
    printf "\nMultipass VM has stopped, you can restart it with\n\tmultipass start %s\n" "$MULTIPASS_VM_NAME"

    exit 0
fi

printf "\nNo k3d instance or multipass vm, exiting...\n"
exit 1
