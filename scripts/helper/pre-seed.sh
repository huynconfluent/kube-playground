#!/bin/sh

# ./preseed.sh -o OPERATOR_VERSION -c CP_VERSION -t TAG_VERSION -m CONTROL_CENTER_NEXT_GEN_VERSION

# TODO: add option for iron bank images?
# docker.com daily pull limits
# unauthenticate = 100 pulls within 6 hours so roughly 400 pulls a day
# authenticated = 200 pulls within 6 hours so roughly 800 pulls a day

BASE_DIR=$(pwd)
REQUIRED_PKG="docker curl gum"
CFK_VERSION=""
CP_VERSION=""
CMF_VERSION=""
CPC_VERSION=""
FLINK_VERSION=""
CONTROL_CENTER_NEXT_GEN_VERSION=""
REPO_NAME="confluentinc"
CFK_IMAGES=("confluent-init-container" "confluent-operator")
BASE_CP_IMAGES=("cp-zookeeper" "cp-server" "cp-kafka" "cp-schema-registry" "cp-kafka-connect" "cp-server-connect" "cp-kafka-rest" "cp-ksqldb-server")
LEGACY_CONTROL_CENTER_IMAGES=("cp-enterprise-control-center")
NEXT_GEN_CP_IMAGES=("cp-enterprise-control-center-next-gen" "cp-enterprise-alertmanager" "cp-enterprise-prometheus")
FLINK_IMAGES=("cp-flink")
CMF_IMAGES=("cp-cmf")
CPC_IMAGES=("cpc-gateway")
PULL_LIMIT_THRESHOLD="20"
IMG_TYPE=("default" "arm64" "ubi8" "ubi9" "ubi8.arm64" "ubi9.arm64")
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
            if [ "$(echo $CPC_VERSION | grep -cE '^[0-9]+\.[0-9]+\.[0-9]+$')" -ne 1 ]; then
                printf "CPC Gateway Version not recognized\n"
                usage
            fi
            ;;
        b)
            CMF_VERSION="$OPTARG"
            if [ "$(echo $CMF_VERSION | grep -cE '^[0-9]+\.[0-9]+\.[0-9]+$')" -ne 1 ]; then
                printf "CMF Version not recognized\n"
                usage
            fi
            ;;
        *)
            usage
            ;;
    esac
done

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

image_pull () {

    l_image="$1"
    l_tag="$2"

    printf "Pulling %s:%s....\n" "$l_image" "$l_tag"
    docker pull $l_image:$l_tag
}

check_pull_limit () {
    token=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)
    remaining_pulls=$(curl -s --head -H "Authorization: Bearer $token" https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest | grep -i 'ratelimit-remaining' | sed -E "s/.*: ([0-9]+);.*/\1/")
    if [ "$remaining_pulls" -lt "$PULL_LIMIT_THRESHOLD" ]; then
        printf "Remaining Pulls is less than the threshold\n"
        printf "Consider logging into Docker to increase pull limits...\n"
        printf "Remaining Pulls: %s\nPull Threshold: %s\n" "$remaining_pulls" "$PULL_LIMIT_THRESHOLD"
        printf "exiting....\n"
        exit 1
    fi
}

menu () {
    
    # Choose CFK Version
    while [ ! -n "$CFK_VERSION" ]; do
        CFK_VERSION=$(gum input --placeholder "CFK Version, e.g. 3.0.0")
        if [ "$(echo $CFK_VERSION | grep -cE '^[0-9]+\.[0-9]+\.[0-9]+$')" -ne 1 ]; then
            printf "CFK Version not in valid format!!\n"
            CFK_VERSION=""
        fi
    done

    # convert CFK tp Operator Image Version
    operator_version_convert

    # Choose CP Version
    while [ ! -n "$CP_VERSION" ]; do
        CP_VERSION=$(gum input --placeholder "CP Version, e.g. 8.0.0")
        if [ "$(echo $CP_VERSION | grep -cE '^[0-9]+\.[0-9]+\.[0-9]+$')" -ne 1 ]; then
            printf "CP Version not in valid format!!\n"
            CP_VERSION=""
        fi
    done

    # Download Control Center Next Gen?
    if [ -z "$CONTROL_CENTER_NEXT_GEN_VERSION" ]; then
        gum confirm "Download C3 Next Gen" && skip_next_gen="false" || skip_next_gen="true"
        # Choose C3 Next Gen Version
        if [ "$skip_next_gen" == "false" ]; then
            while [ ! -n "$CONTROL_CENTER_NEXT_GEN_VERSION" ]; do
                CONTROL_CENTER_NEXT_GEN_VERSION=$(gum input --placeholder "C3 Next Gen Version, e.g. 2.2.0")
                if [ "$(echo $CONTROL_CENTER_NEXT_GEN_VERSION | grep -cE '^[0-9]+\.[0-9]+\.[0-9]+$')" -ne 1 ]; then
                    printf "C3 Next Gen Version not in valid format!!\n"
                    CONTROL_CENTER_NEXT_GEN_VERSION=""
                fi
            done
        fi
    fi

    # Download Flink
    if [ -z "$FLINK_VERSION" ]; then
        gum confirm "Download Flink" && skip_flink="false" || skip_flink="true"
        # Choose Flink Version
        if [ "$skip_flink" == "false" ]; then
            while [ ! -n "$FLINK_VERSION" ]; do
                FLINK_VERSION=$(gum input --placeholder "Flink Version, e.g. 2.0.1-cp1")
                if [ "$(echo $FLINK_VERSION | grep -cE '^[0-9]+\.[0-9]+\..*$')" -ne 1 ]; then
                    printf "Flink Version not in valid format!!\n"
                    FLINK_VERSION=""
                fi
            done
        fi
    fi

    # Download CMF
    if [ -z "$CMF_VERSION" ]; then
        gum confirm "Download CMF" && skip_cmf="false" || skip_cmf="true"
        # Choose CMF Version
        if [ "$skip_cmf" == "false" ]; then
            while [ ! -n "$CMF_VERSION" ]; do
                CMF_VERSION=$(gum input --placeholder "CMF Version, e.g. 2.0.1")
                if [ "$(echo $CMF_VERSION | grep -cE '^[0-9]+\.[0-9]+\.[0-9]+$')" -ne 1 ]; then
                    printf "CMF Version not in valid format!!\n"
                    CMF_VERSION=""
                fi
            done
        fi
    fi

    # Download CPC Gateway
    if [ -z "$CPC_VERSION" ]; then
        gum confirm "Download CPC Gateway" && skip_cpc="false" || skip_cpc="true"
        # Choose CPC Gateway Version
        if [ "$skip_cpc" == "false" ]; then
            while [ ! -n "$CPC_VERSION" ]; do
                CPC_VERSION=$(gum input --placeholder "CPC Gateway Version, e.g. 1.2.0")
                if [ "$(echo $CPC_VERSION | grep -cE '^[0-9]+\.[0-9]+\.[0-9]+$')" -ne 1 ]; then
                    printf "CPC Gateway Version not in valid format!!\n"
                    CPC_VERSION=""
                fi
            done
        fi
    fi

    # Choose image type
    if [ -z "$TAG_VERSION" ]; then
        printf "Choose an Image type:\n"
        TAG_VERSION=$(gum choose --limit 1 "${IMG_TYPE[@]}")
        if [ "$TAG_VERSION" == "default" ]; then
            # null out for 'default'
            TAG_VERSION=""
        else
            TAG_VERSION=".$TAG_VERSION"
        fi
    fi
    
    # Multi Select Containers to download
    images=("${BASE_CP_IMAGES[@]}")
    if [ "$skip_next_gen" == "true" ]; then
        images+=("${LEGACY_CONTROL_CENTER_IMAGES[@]}")
    fi
    if [ "skip_flink" == "false" ]; then
        images+=("${FLINK_IMAGES[@]}")
    fi
    if [ "skip_cmf" == "false" ]; then
        images+=("${CMF_IMAGES[@]}")
    fi
    if [ "skip_cpc" == "false" ]; then
        images+=("${CPC_IMAGES[@]}")
    fi

    choice_array=($(gum choose --no-limit --header "Choose components to download" "${images[@]}"))

    # add to choice_array
    choice_array+=("${CFK_IMAGES[@]}")
    # if c3 next gen
    if [ "$skip_next_gen" == "false" ]; then
        choice_array+=("${NEXT_GEN_CP_IMAGES[@]}")
    fi

    # Check docker pull limit
    check_pull_limit

    # choose container images to download
    for choice in "${choice_array[@]}"; do
        case "$choice" in
            "confluent-operator")
                #printf "Downloading %s....\n" "$REPO_NAME/$choice:${OPERATOR_VERSION}${TAG_VERSION}"
                image_pull "$REPO_NAME/$choice" "${OPERATOR_VERSION}${TAG_VERSION}"
                ;;
            "confluent-init-container")
                #printf "Downloading %s....\n" "$REPO_NAME/$choice:${CFK_VERSION}${TAG_VERSION}"
                image_pull "$REPO_NAME/$choice" "${CFK_VERSION}${TAG_VERSION}"
                ;;
            "cp-enterprise-control-center-next-gen"|"cp-enterprise-alertmanager"|"cp-enterprise-prometheus")
                #printf "Downloading %s....\n" "$REPO_NAME/$choice:${CONTROL_CENTER_NEXT_GEN_VERSION}${TAG_VERSION}"
                image_pull "$REPO_NAME/$choice" "${CONTROL_CENTER_NEXT_GEN_VERSION}${TAG_VERSION}"
                ;;
            "cp-flink")
                #printf "Downloading %s....\n" "$REPO_NAME/$choice:${FLINK_VERSION}"
                image_pull "$REPO_NAME/$choice" "${FLINK_VERSION}"
                ;;
            "cp-cmf")
                if [ "$TAG_VERSION" == "arm64" ]; then
                    #printf "Downloading %s....\n" "$REPO_NAME/$choice:${CMF_VERSION}-arm64"
                    image_pull "$REPO_NAME/$choice" "${CMF_VERSION}-amr64"
                else
                    #printf "Downloading %s....\n" "$REPO_NAME/$choice:${CMF_VERSION}${TAG_VERSION}"
                    image_pull "$REPO_NAME/$choice" "${CMF_VERSION}${TAG_VERSION}"
                fi
                ;;
            "cpc-gateway")
                #printf "Downloading %s....\n" "$REPO_NAME/$choice:${CPC_VERSION}${TAG_VERSION}"
                image_pull "$REPO_NAME/$choice" "${CPC_VERSION}${TAG_VERSION}"
                ;;
            *)
                # assuming it's just a cp component
                #printf "Downloading %s....\n" "$REPO_NAME/$choice:${CP_VERSION}${TAG_VERSION}"
                image_pull "$REPO_NAME/$choice" "${CP_VERSION}${TAG_VERSION}"
                ;;
        esac

    done

    # push to Openshift?
    gum confirm "Push to CRC Openshift?" && push="true" || push="false"
    if [ "$push" == "true" ]; then
        printf "Building args\n"
        l_args="-o $CFK_VERSION -c $CP_VERSION"
        # build argument
        if [ "$skip_next_gen" == "false" ]; then
            l_args+=" -m $CONTROL_CENTER_NEXT_GEN_VERSION"
        fi
        if [ "$skip_flink" == "false" ]; then
            l_args+=" -f $FLINK_VERSION"
        fi
        if [ "$skip_cmf" == "false" ]; then
            l_args+=" -b $CMF_VERSION"
        fi
        if [ "$skip_cpc" == "false" ]; then
            l_args+=" -g $CPC_VERSION"
        fi

        cmd="$BASE_DIR/scripts/helper/push-to-crc-registry.sh $l_args"
        # call push
        #printf "CMD: %s\n" "$cmd"
        eval $cmd 
    fi

    printf "Done!!\n"
}

# Start
menu
