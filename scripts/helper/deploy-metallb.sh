#!/bin/sh

# Usage:
#   ./deploy-metallb.sh

BASE_DIR=$(pwd)
REQUIRED_PKG="kubectl curl"
METALLB_MANIFEST="https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml"
GEN_DIR="$BASE_DIR/generated/metallb"
OPENSHIFT=false
OPTIND=1
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

# flags
usage () {
    printf "Usage: $0 [-o]\n"
    printf "\t-o                                    (optional) deploy in openshift\n"
    printf "\t-h                                    help menu\n"
    exit 1
}
 
while getopts "o" opt; do
    case $opt in
        o)
            OPENSHIFT=true
            ;;
        *)
            usage
            ;;
    esac
done
 
#printf "\n\n=======Installing MetalLB========\n"
source $BASE_DIR/scripts/system/header.sh -t "Installing MetalLB"

# Check for local asset before pulling
if [ ! -f "$GEN_DIR/metallb-native.yaml" ]; then
    mkdir -p $GEN_DIR
    curl --retry 3 --retry-delay 5 -o $GEN_DIR/metallb-native.yaml -L -O $METALLB_MANIFEST 

    # error handling
    if [ ! -f "$GEN_DIR/metallb-native.yaml" ]; then
       printf "Failed to download metallb manifest...\n"
       exit 1
    fi
fi

kubectl apply -f "${GEN_DIR}/metallb-native.yaml"

# For Openshift deployment
if [ "$OPENSHIFT" == "true" ]; then
    if [ "$(which oc)" ]; then
        oc adm policy add-scc-to-user anyuid -z controller -n metallb-system
        oc adm policy add-scc-to-user privileged -z speaker -n metallb-system
    fi
fi

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
