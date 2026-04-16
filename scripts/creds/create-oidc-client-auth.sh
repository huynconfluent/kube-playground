#!/bin/sh

# ./create-oidc-client-auth.sh -u "client_id" -p "client_password" -n "namespace" -c

BASE_DIR=$(pwd)
GEN_DIR="$BASE_DIR/generated/creds/oidc"
CMD_GEN_DIR="$GEN_DIR/cmd"
DEPLOY_CLEAN=false
REQUIRED_PKG="jq"
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
    printf "Usage: $0 [-u] [string] [-n] [string] [-c]\n"
    printf "\t-u [client_id]                        (required) client id\n"
    printf "\t-p [client_password]                  (required) client password\n"
    printf "\t-n [namespace]                        (required) kubernetes namesapce to use in script, e.g. confluent\n"
    printf "\t-c                                    (optional) clean deployment\n"
    exit 1
}

while getopts "u:p:n:c" opt; do
    case $opt in
        u)
            CLIENT_ID=$OPTARG
            ;;
        p)
            CLIENT_PASSWORD=$OPTARG
            ;;
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
if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_PASSWORD" ] || [ -z "$NAMESPACE" ]; then
    printf "Error: $0 requires arguments\n"
    usage
fi

generate_bash_script () {

    l_username=$1
    l_namespace=$2

    cmd="-n \$NAMESPACE create secret generic oidc-$l_username --from-file=oidcClientSecret.txt=$GEN_DIR/files/$l_username-oidcClientSecret.txt"
    file_name="create-oidc-$l_username-secret.sh"

    # uncomment to debug
    #printf "\nKubectl Command: eval kubectl|oc %s\n" "$cmd"

    printf "#!/bin/sh\n\n" > $GEN_DIR/cmd/$file_name
    printf "# ./$file_name [kubectl|oc] [namespace]\n\n" >> $GEN_DIR/cmd/$file_name
    printf "KCMD=\${1:-kubectl}\n" >> $GEN_DIR/cmd/$file_name
    printf "NAMESPACE=\${2:-%s}\n" "$NAMESPACE" >> $GEN_DIR/cmd/$file_name
    printf "eval \"\$KCMD %s\"\n" "$cmd" >> $GEN_DIR/cmd/$file_name
    chmod +x "$GEN_DIR/cmd/$file_name"

    printf "Created bash script at %s\n" "$GEN_DIR/cmd/$file_name"
}

generate_cred_file () {

    l_username=$1
    l_password=$2
    
    # create oidcClientSecret.txt
    printf "Creating oidcClientSecret.txt for %s\n" "$l_username"
    printf "clientId=%s\nclientSecret=%s\n" "$l_username" "$l_password" > "$GEN_DIR/files/$l_username-oidcClientSecret.txt"

}


source $BASE_DIR/scripts/system/header.sh -t "Auto Generating OIDC Client Secret Assets"

# remove generated files?
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


generate_cred_file "$CLIENT_ID" "$CLIENT_PASSWORD"
generate_bash_script "$CLIENT_ID" "$NAMESPACE"
