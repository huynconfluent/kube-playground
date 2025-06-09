#!/bin/sh

REQUIRED_PKG="k3d helm kubectl"
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

# delete k3d
printf "\nDeleting K3D Cluster.......\n"
k3d cluster delete $K3D_CLUSTER_NAME
