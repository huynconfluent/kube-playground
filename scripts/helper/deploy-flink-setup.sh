#!/bin/sh

# ./deploy-flink.sh -c "CERT_MANAGER_VERSION" -f "FLINK_OPERATOR_VERSION" -m "CMF_VERSION"

OPTIND=1
REQUIRED_PKG="kubectl helm yq"
CERT_MANAGER_VER=""
FLINK_OPER_VER=""
CMF_VER=""
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
    printf "Usage: $0 [-c] [CERT_MANAGER_VERSION] [-f] [FLINK_OPERATOR_VERSION] [-m] [CMF_VERSION] [-o]\n"
    printf "\t-c 1.19.2         (optional) Cert Manager Version to deploy\n"
    printf "\t-f 1.130.2        (optional) Flink Operator Version to deploy\n"
    printf "\t-m 2.3.1          (optional) Confluent Manager for Apache Flink Version to deploy\n"
    printf "\t-o                (optional) Deploy in Openshift\n"
    exit 1
}

while getopts "c:f:m:" opt; do
    case $opt in
        c)
            CERT_MANAGER_VER=$OPTARG
            ;;
        f)
            FLINK_OPER_VER=$OPTARG
            ;;
        m)
            CMF_VER=$OPTARG
            ;;
        o)
            OPENSHIFT=true
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "$CERT_MANAGER_VER" ]; then
    # if empty, set to .env
    CERT_MANAGER_VER="$CERT_MANAGER_VERSION"
fi

if [ -z "$FLINK_OPER_VER" ]; then
    # if empty, set to .env
    FLINK_OPER_VER="$FLINK_OPERATOR_VERSION"
fi

if [ -z "$CMF_VER" ]; then
    # if empty, set to .env
    CMF_VER="$CMF_VERSION"
fi

source $BASE_DIR/scripts/system/header.sh -t "Deploy Flink"
# Call deploy cert-manager
source $BASE_DIR/scripts/helper/deploy-cert-manager.sh -v "$CERT_MANAGER_VER"
# Call cp-flink
source $BASE_DIR/scripts/helper/deploy-flink-operator.sh -v "$FLINK_OPER_VER" -w "$CFK_NAMESPACE,$FLINK_OPERATOR_NAMESPACE"
# Call deploy-cmf
if [ "$OPENSHIFT" == "true" ]; then
    source $BASE_DIR/scripts/helper/deploy-cmf.sh -v "$CMF_VER" -n "$CMF_NAMESPACE" -o
else
    source $BASE_DIR/scripts/helper/deploy-cmf.sh -v "$CMF_VER" -n "$CMF_NAMESPACE"
fi
