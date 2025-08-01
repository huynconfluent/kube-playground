#!/bin/sh

# ./generate-ssl-scripts.sh <component> <gen_dir> <namespace> <fullchain> <privkey> <cacerts>

HOME_DIR=$(pwd)
REQUIRED_PKG="kubectl yq jq"
set -o allexport; source .env; set +o allexport

COMPONENT=$1
GEN_DIR="$2"
GEN_DIR_SSL_CMD="$GEN_DIR/cmd"
NAMESPACE=$3
FULLCHAIN_PATH=$4
CACERTS_PATH=$5
PRIVKEY_PATH=$6

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

if [ ! -d "$GEN_DIR" ]; then
    printf "\nGenerated Directory Path UNKNOWN...."
    printf "\nPath: %s\n" "$GEN_DIR"
    exit 1
fi

if [[ ! -f "$FULLCHAIN_PATH" ]] || [[ ! -f "$CACERTS_PATH" ]] || [[ ! -f "$PRIVKEY_PATH" ]]; then
    printf "\nMissing Certificate File..."
    printf "\nFULLCHAIN_PATH: %s" "$FULLCHAIN_PATH"
    printf "\nPRIVKEY_PATH: %s" "$PRIVKEY_PATH"
    printf "\nCACERTS_PATH: %s\n" "$CACERTS_PATH" 
    exit 1
fi

generate_bash_script () {

    cmd="kubectl -n $NAMESPACE create secret generic tls-$COMPONENT --from-file=fullchain.pem=$FULLCHAIN_PATH --from-file=cacerts.pem=$CACERTS_PATH --from-file=privkey.pem=$PRIVKEY_PATH"
    file_name="create-tls-$COMPONENT-secret.sh"
    
    printf "\nKubectl Command: %s\n" "$cmd"

    # Create cmd direcotry for component
    if [ ! -d "$GEN_DIR_SSL_CMD/$COMPONENT" ]; then
        printf "\nMaking Command directory in %s...\n" "$GEN_DIR_SSL_CMD/$COMPONENT"
        mkdir -p "$GEN_DIR_SSL_CMD/$COMPONENT"
    fi

    printf "#!/bin/sh\n%s\n" "$cmd" > $GEN_DIR_SSL_CMD/$COMPONENT/$file_name
    chmod +x "$GEN_DIR_SSL_CMD/$COMPONENT/$file_name"

    printf "\nCreated bash script at %s\n" "$GEN_DIR_SSL_CMD/$COMPONENT/$file_name"
}

generate_bash_script
