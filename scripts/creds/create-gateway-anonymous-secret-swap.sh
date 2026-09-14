#!/bin/sh

# ./create-gateway-anonymous-secret-swap.sh -n "namespace"

BASE_DIR=$(pwd)
GEN_DIR="$BASE_DIR/generated/creds/gateway/userstore"
CMD_DIR="$GEN_DIR/cmd"
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
    printf "Usage: $0 [-n] [string]\n"
    printf "\t-n namespace                      (required) kubernetes namesapce to use in script, e.g. confluent\n"
    exit 1
}

while getopts "f:n:c" opt; do
    case $opt in
        n)
            NAMESPACE=$OPTARG
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

    # While you can use --from-file, it will just be easier using --from-literal so we don't have to create all those files
    literal_string=$1
    secret_name="gateway-anonymous-store"
    cmd="-n \$NAMESPACE create secret generic $secret_name --from-literal=ANONYMOUS=\\\"confluent-gateway/confluent-gateway-secret\\\""
    file_name="create-gateway-anonymous-secret-swap-secret.sh"
    gen_path="$CMD_DIR/$file_name"

    # uncomment to debug
    #printf "\nKubectl Command: eval kubectl|oc %s\n" "$cmd"

    printf "#!/bin/sh\n\n" > $gen_path
    printf "# ./$file_name [kubectl|oc] [namespace]\n\n" >> $gen_path
    printf "KCMD=\${1:-kubectl}\n" >> $gen_path
    printf "NAMESPACE=\${2:-%s}\n" "$NAMESPACE" >> $gen_path
    printf "eval \"\$KCMD %s\"\n" "$cmd" >> $gen_path
    chmod +x "$gen_path"

    printf "\nCreated Gateway ANONYMOUS Store bash script at %s\n" "$gen_path"

}


source $BASE_DIR/scripts/system/header.sh -t "Generating Gateway ANONYMOUS Secret Store"

if [ ! -d "$CMD_DIR" ]; then
    mkdir -p "$CMD_DIR"
fi

generate_bash_script
