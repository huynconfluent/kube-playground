#!/bin/sh

# ./get-crc-bundle.sh -v 4.21 -p openshift|microshift

BASE_DIR=$(pwd)
CRC_BUNDLE_PATH="$HOME/.crc/cache"
CRC_BASE_URL="https://mirror.openshift.com/pub/openshift-v4/clients/crc/bundles/"
# vfkit for macOS
BUNDLE_PREFIX="crc_vfkit_"
if [ "$(arch)" == "arm64" ]; then
    ARCH="arm64"
else
    ARCH="amd64"
fi
OPTIND=1

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
    printf "Usage: $0 [-v] [string] [-p] [path]\n"
    printf "\t-p                                    (required) preset openshift|microshift\n"
    printf "\t-v                                    (required) version, e.g. 4.21\n"
    printf "\t-h                                    help menu\n"
    exit 1
}

while getopts "p:v:" opt; do
    case $opt in
        v)
            VERSION=$OPTARG
            if [ "$(echo $VERSION | grep -cE '[0-9]+\.[0-9]+\.[0-9]+')" -ne 1 ]; then
                printf "Version: %s ........ is not valid, exiting\n"
                exit 1
            fi
            ;;
        p)
            PRESET=$OPTARG
            if [ "$PRESET" != "openshift" ] && [ "$PRESET" != "microshift" ]; then
                printf "Preset: %s ...... is not valid, exiting\n"
                exit 1
            fi
            ;;
        *)
            usage
            ;;
    esac
done

source $BASE_DIR/scripts/system/header.sh -t "Get CRC bundle"

if [ -z "$PRESET" ] ||  [ -z "$VERSION" ]; then
    printf "Error: $0 requires arguments\n"
    usage
fi

printf "\nCRC Preset: %s\nVersion: %s\nArch: %s\n" "$PRESET" "$VERSION" "$ARCH"

FILENAME="${BUNDLE_PREFIX}${VERSION}_${ARCH}.crcbundle"

printf "Checking if bundle already exists: %s....\n" "$FILENAME"
if [ ! -f "$CRC_BUNDLE_PATH/$FILENAME" ]; then
    printf "CRC Bundle doesn't exist, attempting to download......\n"

    # create path if doesn't exist
    if [ ! -d "$CRC_BUNDLE_PATH" ]; then
        mkdir -p $CRC_BUNDLE_PATH
    fi

    # download via curl
    printf "Attempting to download CRC Bundle from %s\n\n" "$CRC_BASE_URL/$PRESET/$VERSION/$FILENAME"
    curl --retry 3 --retry-delay 5 -o $CRC_BUNDLE_PATH/$FILENAME -L -O $CRC_BASE_URL/$PRESET/$VERSION/$FILENAME
else
    printf "CRC Bundle already exist, skipping...\n"
fi

# file check again
if [ ! -f "$CRC_BUNDLE_PATH/$FILENAME" ]; then
    printf "Something must have gone wrong with download, exiting....\n"
    exit 1
else
    printf "Download succeeded!\n"
fi
