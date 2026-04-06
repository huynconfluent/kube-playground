#!/bin/sh

# TODO: Add in stop to shutdown multipass or not
# TODO: Add teardown options for Terraform and Openshift

set -o allexport; source .env; set +o allexport

source $BASE_DIR/scripts/system/header.sh -t "Shutting Down Kube Playground"

# check if k3d is running
if [ ! -z "$(which k3d)" ]; then
    if k3d cluster list $K3D_CLUSTER_NAME > /dev/null 2>&1; then
        # delete k3d
        printf "\nDeleting K3D Cluster.......\n"
        k3d cluster delete $K3D_CLUSTER_NAME
        exit 0
    fi

    printf "No k3d Cluster Found...\n"
fi

# check if multipass is deployed
if [ ! -z "$(which multipass)" ]; then
    if [ "$(multipass list | grep -c $MULTIPASS_VM_NAME)" -ne 0 ]; then
        # stop multipass vm if running
        if [ "$(multipass list | grep $MULTIPASS_VM_NAME | awk '{print $2}' | grep -ic running)" -ge 1 ]; then
            printf "\nStopping Multipass VM.....\n"
            multipass stop $MULTIPASS_VM_NAME
            printf "\nMultipass VM has stopped, you can restart it with\n\tmultipass start %s\n" "$MULTIPASS_VM_NAME"
            exit 0
        fi
    fi

    printf "No Multipass VM Found...\n"
fi

# check if CRC is running
if [ ! -z "$(which crc)" ]; then
    if [ "$(crc status 2>&1 | grep -ic 'crc setup')" -ne 1 ]; then
        if [ "$(crc status 2>&1 | grep -i 'crc vm:' | grep -ic 'running')" -eq 1 ]; then
            printf "CRC found, stopping.....\n"
            crc stop
            printf "CRC has stopped, you can restart it with \n\tcrc start\n"
            exit 0
        fi
    fi

    printf "No CRC VM Found...\n"
fi

printf "\nNothing managed by kube-playground found running, exiting...\n"
exit 1
