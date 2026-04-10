#!/bin/sh

BASE_DIR=$(pwd)
REQUIRED_PKG="docker"
OC_PROJECT_NAME="confluent"
OC_REGISTRY="default-route-openshift-image-registry.apps-crc.testing"
OPTIND=1
set -o allexport; source .env; set +o allexport

#
TAGGED=($(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "^$OC_REGISTRY"))

for tag in "${TAGGED[@]}"; do
    #printf "TAG: %s\n" "$tag"
    docker rmi "$tag"
done
