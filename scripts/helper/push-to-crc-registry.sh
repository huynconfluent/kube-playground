#!/bin/sh

# ./push-to-crc-registry.sh -o CFK_VERSION -c CP_VERSION -m CONTROL_CENTER_NEXT_GEN_VERSION -t IMAGE_TYPE

BASE_DIR=$(pwd)
REQUIRED_PKG="docker skopeo crc oc"
OPERATOR_VERSION=""
CP_VERSION=""
CONTROL_CENTER_NEXT_GEN_VERSION=""
FLINK_VERSION=""
CMF_VERSION=""
CPC_VERSION=""
TAG_VERSION=""
OC_PROJECT_NAME="confluent"
OC_REGISTRY="default-route-openshift-image-registry.apps-crc.testing"
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
    printf "Usage: $0 [-o] [string] [-c] [string] [-m] [string] [-t] [string] [-f] [string] [-g] [string] [-b] [string]\n"
    printf "\t-o                                    (required) cfk version, e.g. 3.2.0\n"
    printf "\t-c                                    (required) cp version, e.g. 8.0.0\n"
    printf "\t-t                                    (optional) tag version type, e.g. ubi8, ubi9, arm64, ubi8.arm64, etc\n"
    printf "\t-m                                    (optional) control center next gen tag version, e.g. 2.0.0\n"
    printf "\t-f                                    (optional) flink version, e.g. 2.0.1-cp1\n"
    printf "\t-g                                    (optional) cpc gateway version, e.g. 1.2.0\n"
    printf "\t-b                                    (optional) cmf version, e.g. 2.0.0\n"
    printf "\t-h                                    help menu\n"
    exit 1
}

while getopts "o:c:m:t:f:g:b:" opt; do
    case $opt in
        o)
            CFK_VERSION=$OPTARG
            if [ "$(echo $CFK_VERSION | grep -cE '^[0-9]+\.[0-9]+\.[0-9]+$')" -ne 1 ]; then
                printf "CFK Version not recognized\n"
                usage
            fi
            ;;
        c)
            CP_VERSION=$OPTARG
            if [ "$(echo $CP_VERSION | grep -cE '^[0-9]+\.[0-9]+\.[0-9]+$')" -ne 1 ]; then
                printf "Confluent Platform Version not recognized\n"
                usage
            fi
            ;;
        m)
            CONTROL_CENTER_NEXT_GEN_VERSION=$OPTARG
            if [ "$(echo $CONTROL_CENTER_NEXT_GEN_VERSION | grep -cE '^[0-9]+\.[0-9]+\.[0-9]+$')" -ne 1 ]; then
                printf "Control Center Next Gen Version not recognized\n"
                usage
            fi
            ;;
        t)
            TAG_VERSION=".$OPTARG"
            ;;
        f)
            FLINK_VERSION="$OPTARG"
            ;;
        g)
            CPC_VERSION="$OPTARG"
            if [ "$(echo $CPC_VERSION | grep -ce '^[0-9]+\.[0-9]+\.[0-9]+$')" -ne 1 ]; then
                printf "CPC Gateway Version not recognized\n"
                usage
            fi
            ;;
        b)
            CMF_VERSION="$OPTARG"
            if [ "$(echo $CMF_VERSION | grep -ce '^[0-9]+\.[0-9]+\.[0-9]+$')" -ne 1 ]; then
                printf "CMF Version not recognized\n"
                usage
            fi
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "$CFK_VERSION" ] && [ -z "$CP_VERSION" ]; then
    printf "Error: $0 requires arguments\n"
    usage
fi

openshift_check () {
    # is openshift cluster running?
    if [ "$(crc status 2>&1 | grep -ic 'crc setup')" -ne 1 ]; then
        if [ "$(crc status 2>&1 | grep -i 'crc vm:' | grep -ic 'running')" -eq 1 ]; then
            printf "CRC VM is running\n"
        else
            printf "CRC VM is not running, exiting....\n"
            exit 1
        fi
    else
        printf "Doesn't seem like CRC VM is setup, exiting...\n"
        exit 1
    fi
    
    # ensure oc command is good.
    if [ "$(oc get nodes 2>&1 | grep -ic 'ready')" -ne 1 ]; then
        printf "Might not be logged in, let's try logging in...\n"
        oc login -u kubeadmin https://api.crc.testing:6443
    else
        printf "Successful!\n"
    fi
    
    # check for project?
    if [ "$(oc get projects -o name | grep -c $OC_PROJECT_NAME)" -lt 1 ]; then
        printf "Creating OC Project....\n"
        oc new-project $OC_PROJECT_NAME
    fi
}

operator_version_convert () {

    if [ "$(grep -c $CFK_VERSION $BASE_DIR/configs/cfk/version_mapping.json)" -ge 1 ]; then
        OPERATOR_VERSION=$(jq -r 'to_entries[] | select(.key == '\"$CFK_VERSION\"') | .value' $BASE_DIR/configs/cfk/version_mapping.json)
        if [ -z "$OPERATOR_VERSION" ]; then
            printf "CFK Version not valid, exiting...\n"
            exit 1
        fi
    else
        printf "\nCFK Version could not be determined, exiting....\n"
        exit 1
    fi
}

# Start
openshift_check
operator_version_convert

# Get Registry hostname
OC_REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')
OC_USER="kubeadmin"
OC_PASSWORD=$(oc whoami -t)

LOCAL_INIT_IMAGE=($(docker images --format "{{.Repository}} {{.Tag}}" | grep -E '^confluentinc/confluent-init-container' | grep -E "${CFK_VERSION}${TAG_VERSION}$"  | awk -F'[/ ]' '{print $(NF-1) ":" $NF}' | grep -v "<none>"))
LOCAL_OPERATOR_IMAGE=($(docker images --format "{{.Repository}} {{.Tag}}" | grep -E '^confluentinc/confluent-operator' | grep -E "${OPERATOR_VERSION}${TAG_VERSION}$"  | awk -F'[/ ]' '{print $(NF-1) ":" $NF}' | grep -v "<none>"))
COMBINED_IMAGES=("${LOCAL_INIT_IMAGE[@]}" "${LOCAL_OPERATOR_IMAGE[@]}")
if [ -z "$CONTROL_CENTER_NEXT_GEN_VERSION" ]; then
    # Ignore images if not targetting next gen
    LOCAL_CONTROLCENTER_IMAGES=()
else
    LOCAL_CONTROLCENTER_IMAGES=($(docker images --format "{{.Repository}} {{.Tag}}" | grep -E '^confluentinc/cp-enterprise-(alertmanager|prometheus|control-center-next-gen)' | grep -E "${CONTROL_CENTER_NEXT_GEN_VERSION}${TAG_VERSION}$"  | awk -F'[/ ]' '{print $(NF-1) ":" $NF}' | grep -v "<none>"))
fi
# add in flink images
if [ ! -z "$FLINK_VERSION" ]; then
    LOCAL_FLINK_IMAGES=($(docker images --format "{{.Repository}} {{.Tag}}" | grep -E '^confluentinc' | grep -E "${FLINK_VERSION}$"  | awk -F'[/ ]' '{print $(NF-1) ":" $NF}' | grep -v "<none>"))
    COMBINED_IMAGES+=("${LOCAL_FLINK_IMAGES[@]}")
fi

# add in cpc gateway images
if [ ! -z "$CPC_VERSION" ]; then
    LOCAL_CPC_IMAGES=($(docker images --format "{{.Repository}} {{.Tag}}" | grep -E '^confluentinc' | grep -E "${CPC_VERSION}${TAG_VERSION}$"  | awk -F'[/ ]' '{print $(NF-1) ":" $NF}' | grep -v "<none>"))
    COMBINED_IMAGES+=("${LOCAL_CPC_IMAGES[@]}")

fi

# add in cmf images
if [ ! -z "CMF_VERSION" ]; then
    LOCAL_CMF_IMAGES=($(docker images --format "{{.Repository}} {{.Tag}}" | grep -E '^confluentinc' | grep -E "${CMF_VERSION}$"  | awk -F'[/ ]' '{print $(NF-1) ":" $NF}' | grep -v "<none>"))
    COMBINED_IMAGES+=("${LOCAL_CMF_IMAGES[@]}")

fi

# add in cp images
LOCAL_CP_IMAGES=($(docker images --format "{{.Repository}} {{.Tag}}" | grep -E '^confluentinc' | grep -E "${CP_VERSION}${TAG_VERSION}$"  | awk -F'[/ ]' '{print $(NF-1) ":" $NF}' | grep -v "<none>"))
COMBINED_IMAGES=("${LOCAL_CONTROLCENTER_IMAGES[@]}" "${LOCAL_CP_IMAGES[@]}")

for img in "${COMBINED_IMAGES[@]}"; do
    printf "Image: %s\n" "$img"
    # tag image first
    cmd="docker tag confluentinc/$img $OC_REGISTRY/$OC_PROJECT_NAME/$img"
    eval $cmd
    #printf "TAG: %s\n" "$cmd"
    # push image
    cmd="skopeo copy --dest-tls-verify=false docker-daemon:$OC_REGISTRY/confluentinc/$img docker://$OC_REGISTRY/$OC_PROJECT_NAME/$img --dest-creds $OC_USER:$OC_PASSWORD"
    eval $cmd
    #printf "PUSH: %s\n" "$cmd"
done

printf "Images pushed to CRC Registry!!!\n\n"
# list images
oc get is
