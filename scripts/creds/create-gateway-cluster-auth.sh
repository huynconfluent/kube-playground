#!/bin/sh

# ./create-gateway-cluster-auth.sh -n "namespace" -c

BASE_DIR=$(pwd)
GEN_DIR="$BASE_DIR/generated/creds/gateway/cluster"
DEPLOY_CLEAN=false
OPTIND=1
REQUIRED_PKG="jq"
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
    printf "Usage: $0 [-n] [string] [-c]\n"
    printf "\t-n namespace                      (required) kubernetes namesapce to use in script, e.g. confluent\n"
    printf "\t-c                                (optional) clean deployment\n"
    exit 1
}

while getopts "n:c" opt; do
    case $opt in
        n)
            NAMESPACE=$OPTARG
            ;;
        c)
            DEPLOY_CLEAN=true
            ;;
        *)
            usage
            ;;
    esac
done

# ensure input has value
if [ -z "$NAMESPACE" ]; then
    printf "Error: $0 requires arguments\n"
    usage
fi

generate_bash_script () {

    # generate a jaas vs json?
    auth_type=$1
    file_path="$GEN_DIR/files/$auth_type-jaas.conf"
    if [ "$auth_type" == "plain" ]; then
        secret_name="gateway-cluster-pjaas"
    elif [ "$auth_type" == "oauth" ]; then
        secret_name="gateway-cluster-ojaas"
    else
        printf "Auth Type not recognized: %s, exiting...\n"
        exit 1
    fi
    cmd="-n \$NAMESPACE create secret generic $secret_name --from-file=$auth_type-jaas.conf=$file_path"
    file_name="create-gateway-cluster-$auth_type-secret.sh"
    gen_path="$GEN_DIR/cmd/$file_name"

    if [ "$auth_type" == "plain" ]; then
        echo "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"%s\" password=\"%s\";" > "$file_path"
    elif [ "$auth_type" == "oauth" ]; then
        echo "org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required clientId=\"%s\" clientSecret=\"%s\";" > "$file_path"
    else
        printf "auth_type not recognized: %s, exiting...\n" "$auth_type"
        exit 1
    fi

    # uncomment to debug
    #printf "\nKubectl Command: eval kubectl|oc %s\n" "$cmd"

    printf "#!/bin/sh\n\n" > $gen_path
    printf "# ./$file_name [kubectl|oc] [namespace]\n\n" >> $gen_path
    printf "KCMD=\${1:-kubectl}\n" >> $gen_path
    printf "NAMESPACE=\${2:-%s}\n" "$NAMESPACE" >> $gen_path
    printf "eval \"\$KCMD %s\"\n" "$cmd" >> $gen_path
    chmod +x "$gen_path"

    printf "\nCreated Gateway Cluster %s-jaas secret bash script at %s\n" "$auth_type" "$gen_path"

}

source $BASE_DIR/scripts/system/header.sh -t "Generating Gateway Cluster Credentials"

# deploy clean?
if [[ "$DEPLOY_CLEAN" == "true" ]]; then
    printf "Deleting generated files...\n"
    if [ -d "$GEN_DIR" ]; then
        rm -r "$GEN_DIR"
    else
        printf "Directory doesn't exist, skipping...\n"
    fi
fi

if [ ! -d "$GEN_DIR" ]; then
    mkdir -p "$GEN_DIR/cmd"
    mkdir -p "$GEN_DIR/files"
fi

# create cmd for sasl/oauthbearer and sasl/plain
generate_bash_script "plain"
generate_bash_script "oauth"
