#!/bin/sh

# Usage:
#   ./deploy-metallb.sh

BASE_DIR=$(pwd)
REQUIRED_PKG="kubectl"
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

#printf "\n\n=======Installing MetalLB========\n"
source $BASE_DIR/scripts/system/header.sh -t "Installing MetalLB"

kubectl apply -f "${METALLB_MANIFEST}"

# wait for metalLB to be ready
timeout=$OVERALL_TIMEOUT
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

printf "\n\nApplying MetalLB Configuration...\n"
if [ -f "$BASE_DIR/configs/metallb/config.yaml" ]; then
    kubectl apply -f "$BASE_DIR/configs/metallb/config.yaml"
else
    printf "\nCould not find %s, now exiting....\n" "$BASE_DIR/configs/metallb/config.yaml"
    exit 1
fi
printf "\n"
