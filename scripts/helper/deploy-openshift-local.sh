#!/bin/sh

# ./deploy-openshift-local.sh -v 4.21 -p "PULL_SECRET_PATH"

BASE_DIR=$(pwd)
REQUIRED_PKG="crc jq"
DEPLOY_CLEAN=false
PULL_SECRET_PATH=""
OPENSHIFT_VERSION=""
CRC_BUNDLE_PATH="$HOME/.crc/cache"
BUNDLE_PREFIX="crc_vfkit_"
CRC_PRESET="openshift"
CRC_EXTRA_ARGS=""
if [ "$(arch)" == "arm64" ]; then
    ARCH="arm64"
else
    ARCH="amd64"
fi
OPTIND=1
set -o allexport; source .env; set +o allexport

# check for prerequisites
for PKG in $REQUIRED_PKG; do
    if [ -z "$(which ${PKG})" ]; then
        printf "REQUIRED: %s" "${PKG}"
        if [ "$PKG" == "crc" ]; then
            printf "Please manually install CRC via https://console.redhat.com/openshift/create/local\n"
            printf "Please also ensure your Pull Secret is downloaded and stored on your local machine\n"
            exit 1
        else
            printf "\nPlease install %s" "${PKG}"
            printf "\nUsing Brew:"
            printf "\n\tbrew install %s" "${PKG}"
            exit 1
        fi

    fi
done

# flags
usage () {
    printf "Usage: $0 [-v] [string] [-p] [path]\n"
    printf "\t-p                                    (required) pull secret file path\n"
    printf "\t-v                                    (optional) openshift version, e.g. 4.21\n"
    printf "\t-k                                    (optional) CRC Preset openshift|microshift, defaults to openshift\n"
    printf "\t-c                                    (optional) clean deployment (DELETES previous deployments)\n"
    printf "\t-h                                    help menu\n"
    exit 1
}

while getopts "p:v:c" opt; do
    case $opt in
        v)
            OPENSHIFT_VERSION=$OPTARG
            ;;
        p)
            PULL_SECRET_PATH=$OPTARG
            ;;
        k)
            CRC_PRESET=$OPTARG
            if [ "$CRC_PRESET" != "openshift" ] && [ "$CRC_PRESET" != "microshift" ]; then
                printf "Preset not recognized!!\n"
                usage
            fi
            ;;
        c)
            DEPLOY_CLEAN=true
            ;;
        *)
            usage
            ;;
    esac
done

crc_config () {
    # configure CRC
    crc config set consent-telemetry no
    crc config set cpus $CRC_CPU_CORES
    # memory value in MB
    crc config set memory $CRC_MEMORY_MB
    # disk size in GB
    crc config set disk-size $CRC_DISK_SIZE_GB
}

crc_setup () {

    if [ -z "$OPENSHIFT_VERSION" ]; then
        crc setup
    else
        crc setup -b "${CRC_BUNDLE_PATH}/${BUNDLE_PREFIX}${OPENSHIFT_VERSION}_${ARCH}.crcbundle"
    fi
}

crc_start () {
    
    if [ -z "$OPENSHIFT_VERSION" ]; then
        crc start -p "$PULL_SECRET_PATH"
    else
        crc start -p "$PULL_SECRET_PATH" -b "${CRC_BUNDLE_PATH}/${BUNDLE_PREFIX}${OPENSHIFT_VERSION}_${ARCH}.crcbundle"
    fi
}

crc_cleanup () {

    if [ "$(crc status 2>&1 | grep -ic 'crc setup')" -ne 1 ]; then
        # delete crc
        crc delete --force
        # cleanup
        crc cleanup

        printf "CRC Deleted and cleaned up....\n"
    else
        printf "CRC not setup, Nothing to delete, skipping...\n"
    fi
}

get_login_cmd () {

    cmd=$(crc console --credentials | grep 'admin' | sed -E "s/.*'(.*)'/\1/")
    eval $cmd
}

source $BASE_DIR/scripts/system/header.sh -t "Deploying Openshift Local"

# ensure a pull secret is provided
if [ -z "$PULL_SECRET_PATH" ]; then
    printf "Error: $0 requires arguments\n"
    usage
fi

# set version
if [ ! -z "$OPENSHIFT_VERSION" ]; then
    # check if version is valid format
    if [ "$(echo $OPENSHIFT_VERSION | grep -cE '^[0-9]+\.[0-9]+\.[0-9]+$')" -ne 1 ]; then
        printf "Openshift Version not valid: %s, exiting...\n"
        exit 1
    fi
    # check that version exists in cache
    if [ ! -f "${CRC_BUNDLE_PATH}/${BUNDLE_PREFIX}${OPENSHIFT_VERSION}_${ARCH}.crcbundle" ]; then
        printf "Bundle version not found in CRC Cache...\n"
        # procede to download?
        source $BASE_DIR/scripts/helper/get-crc-bundle.sh -v "$OPENSHIFT_VERSION" -p "$CRC_PRESET"
    else
        printf "Bundle version found in CRC Cache!\n"
    fi
else
    # if unset pull CRC version
    CRC_VERSION=$(crc version | grep -i 'openshift version:' | sed -E 's/^openshift version: ([0-9\.]+)$/\1/i')
    printf "Using Default CRC Version Openshift Version: %s\n" "$CRC_VERSION"
fi

printf "\nPull Secret: %s" "$PULL_SECRET_PATH"

# pull-secret validation
if [ ! -f "$PULL_SECRET_PATH" ];then
    printf "\nPull Secret does not exist: %s\n" "$PULL_SECRET_PATH"
    exit 1
fi

if jq empty $PULL_SECRET_PATH > /dev/null 2>&1; then
    printf " ................ Valid JSON\n\n"
else
    printf " ................ JSON is not valid, exiting...\n\n"
    exit 1
fi

# TODO: add a clean deployment option
if [ "$DEPLOY_CLEAN" == "true" ]; then
    printf "Deploying cleanly, will attempt to DELETE previous deployment....\n"
    crc_cleanup
fi

# check if crc is setup
if [ "$(crc status 2>&1 | grep -ic 'crc setup')" -eq 1 ]; then
    printf "CRC has not been setup yet....\nRunning CRC setup....\n"
    crc_setup
    # also run the config
    crc_config
else
    printf "CRC has been setup, skipping...\n"
fi

# check if crc machine exists
if [ "$(crc status 2>&1 | grep -ic 'crc start')" -eq 1 ]; then
    printf "CRC VM has not been started yet....\nRunning CRC Start.....\n"
    crc_start
else
    # is VM running or stopped
    if [ "$(crc status 2>&1 | grep -i 'crc vm:' | grep -ic 'stopped')" -eq 1 ]; then
        printf "CRC VM is stopped.....\nStarting CRC VM.....\n"
        crc start -p "$PULL_SECRET_PATH"
    else
        printf "CRC VM is already running!\n"
    fi
fi

# confirmed CRC vm is running
if [ "$(crc status | grep -i 'crc vm:' | grep -ic 'running')" -eq 1 ]; then
    returned_version=$(crc status | grep -i 'openshift:' | grep -oE '([0-9.]+)')
    printf "\nOpenshift Local successfully deployed!!\n\nOpenShift Version: %s\n\n" "$returned_version"
else
    printf "ERROR, CRC VM status unknown, exiting...\n"
    exit 1
fi

# Login as admin
get_login_cmd

# verify oc cluster
printf "Testing oc command after login....\n"
oc get nodes
printf "\n\n"
