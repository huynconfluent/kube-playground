#!/bin/sh

# ./create-gateway-vault-store-secret.sh -n "namespace"

BASE_DIR=$(pwd)
GEN_DIR="$BASE_DIR/generated/creds/gateway/userstore"
CMD_DIR="$GEN_DIR/cmd"
VAULT_ENDPOINT=""
VAULT_ROOT_TOKEN=""
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
    printf "Usage: $0 [-u] [string] [-t] [string] [-n] [string]\n"
    printf "\t-u url                            (required) Vault url (http://vault-0:8200)\n"
    printf "\t-t token                          (required) Vault Root Token\n"
    printf "\t-n namespace                      (required) kubernetes namesapce to use in script, e.g. confluent\n"
    exit 1
}

while getopts "u:t:n:" opt; do
    case $opt in
        u)
            VAULT_ENDPOINT=$OPTARG
            ;;
        t)
            VAULT_ROOT_TOKEN=$OPTARG
            ;;
        n)
            NAMESPACE=$OPTARG
            ;;
        *)
            usage
            ;;
    esac
done

# ensure input has value
if [ -z "$NAMESPACE" ] || [ -z "$VAULT_ENDPOINT" ] || [ -z "$VAULT_ROOT_TOKEN" ]; then
    printf "Error: $0 requires arguments\n"
    usage
fi

generate_bash_script () {

    secret_name="gateway-vault-config"
    cmd="-n \$NAMESPACE create secret generic $secret_name --from-literal=address=$VAULT_ENDPOINT --from-literal=authToken=$VAULT_ROOT_TOKEN --from-literal=prefixPath=secret/ --from-literal=separator=/"
    file_name="create-gateway-vault-config-secret.sh"
    gen_path="$CMD_DIR/$file_name"

    # uncomment to debug
    #printf "\nKubectl Command: eval kubectl|oc %s\n" "$cmd"

    printf "#!/bin/sh\n\n" > $gen_path
    printf "# ./$file_name [kubectl|oc] [namespace]\n\n" >> $gen_path
    printf "KCMD=\${1:-kubectl}\n" >> $gen_path
    printf "NAMESPACE=\${2:-%s}\n" "$NAMESPACE" >> $gen_path
    printf "eval \"\$KCMD %s\"\n" "$cmd" >> $gen_path
    chmod +x "$gen_path"

    printf "\nCreated Gateway Vault Config Secret bash script at %s\n" "$gen_path"

}

source $BASE_DIR/scripts/system/header.sh -t "Generating Gateway Vault Config Secret"

if [ ! -d "$CMD_DIR" ]; then
    mkdir -p "$CMD_DIR"
fi

generate_bash_script
