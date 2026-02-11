#!/bin/sh

# ./create-basic-auth.sh "restproxy|ksqldb|schemaregistry|connect|controlcenter" "username:password:role,username:password:role,username:password:role" "namespace"
# ./create-basic-auth.sh -p "restproxy|ksqldb|schemaregistry|connect|controlcenter" -u "users" -n "namespace" -c
BASE_DIR=$(pwd)
GEN_DIR="$BASE_DIR/generated/creds/basic"
SERVER_GEN_DIR="$GEN_DIR/server-side"
CLIENT_GEN_DIR="$GEN_DIR/client-side"
CMD_GEN_DIR="$GEN_DIR/cmd"
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
    printf "Usage: $0 [-p] [string] [-u] [string] [-n] [string]\n"
    printf "\t-p [component]                    (required) CP Component, restproxy|ksqldb|schemaregistry|connect|controlcenter|prometheus\n"
    printf "\t-u [username:password:role]       (required) comma separated string\n"
    printf "\t-n namespace                      (required) kubernetes namesapce to use in script, e.g. confluent\n"
    printf "\t-c                                (optional) clean deployment\n"
    exit 1
}

while getopts "p:u:n:c" opt; do
    case $opt in
        p)
            COMPONENT=$OPTARG
            ;;
        u)
            USER_LIST=$OPTARG
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
if [ -z "$COMPONENT" ] || [ -z "$USER_LIST" ] || [ -z "$NAMESPACE" ]; then
    printf "Error: $0 requires arguments\n"
    usage
fi

if [[ "$COMPONENT" != "restproxy" ]] && [[ "$COMPONENT" != "ksqldb" ]] && [[ "$COMPONENT" != "schemaregistry" ]] && [[ "$COMPONENT" != "controlcenter" ]] && [[ "$COMPONENT" != "prometheus" ]] && [[ "$COMPONENT" != "alertmanager" ]] && [[ "$COMPONENT" != "connect" ]]; then
    printf "\nComponent: %s is UNKNOWN, exiting....\n" "$COMPONENT"
    usage
fi

generate_bash_script () {

    secret_name=$1
    file_path=$2
    cmd="-n \$NAMESPACE create secret generic $secret_name --from-file=basic.txt=$file_path"
    file_name="create-$secret_name-secret.sh"
    gen_path="$CMD_GEN_DIR/$file_name"

    # uncomment to debug
    #printf "\nKubectl Command: eval kubectl|oc %s\n" "$cmd"

    printf "#!/bin/sh\n\n" > $gen_path
    printf "# ./$file_name [kubectl|oc] [namespace]\n\n" >> $gen_path
    printf "KCMD=\${1:-kubectl}\n" >> $gen_path
    printf "NAMESPACE=\${2:-%s}\n" "$NAMESPACE" >> $gen_path
    printf "eval \"\$KCMD %s\"\n" "$cmd" >> $gen_path
    chmod +x "$gen_path"

    printf "Created bash script at %s\n" "$gen_path"

}

source $BASE_DIR/scripts/system/header.sh -t "Generating Basic Auth Credentials"

# remove generated files?
if [[ "$DEPLOY_CLEAN" == "true" ]]; then
    printf "Deleting generated files...\n"
    if [ -d "$GEN_DIR" ]; then
        rm -r "$GEN_DIR"
    else
        printf "Directory doesn't exist, skipping...\n"
    fi
fi

if [ ! -d "$SERVER_GEN_DIR/$COMPONENT" ]; then
    mkdir -p "$SERVER_GEN_DIR/$COMPONENT"
fi

if [ ! -d "$CLIENT_GEN_DIR/$COMPONENT" ]; then
    mkdir -p "$CLIENT_GEN_DIR/$COMPONENT"
fi

if [ ! -d "$CMD_GEN_DIR" ]; then
    mkdir -p "$CMD_GEN_DIR"
fi


SERVER_BASIC_AUTH_FILE="$SERVER_GEN_DIR/$COMPONENT/basic.txt"
printf "\nCreating server-side basic.txt for %s in %s\n" "$COMPONENT" "$SERVER_BASIC_AUTH_FILE"
printf "" > "$SERVER_BASIC_AUTH_FILE"

# loop
IFS=',' read -ra USERS <<< "$USER_LIST"
for user in "${USERS[@]}"; do
    # separate based on component, only 3 of them don't "require" a role
    if [[ "$COMPONENT" == "prometheus" ]] || [[ "$COMPONENT" == "alertmanager" ]] || [[ "$COMPONENT" == "connect" ]]; then
        # username+password
        echo "$user" | sed "s/\(.*\):\(.*\):\(.*\)/\1: \2/" >> "$SERVER_BASIC_AUTH_FILE"
    else
        # username+password+role
        echo "$user" | sed "s/\(.*\):\(.*\):\(.*\)/\1: \2,\3/" >> "$SERVER_BASIC_AUTH_FILE"
    fi

    username=$(echo ${user} | awk -F ':' '{ print $1 }')
    password=$(echo ${user} | awk -F ':' '{ print $2 }')

    # client side
    printf "Creating client side %s basic.txt\n" "$component"
    printf "\nAdding %s server-side record in %s...." "$username" "$SERVER_BASIC_AUTH_FILE"
    printf "username=%s\npassword=%s\n" "$username" "$password" > "$CLIENT_GEN_DIR/$COMPONENT/$username-basic.txt"
    printf "\nAdding %s client-side record to %s..." "$username" "$CLIENT_GEN_DIR/$COMPONENT/$username-basic.txt"

    generate_bash_script "basic-client-$username" "$CLIENT_GEN_DIR/$COMPONENT/$username-basic.txt"
done

# create server side cmd
generate_bash_script "basic-server-$COMPONENT" "$SERVER_BASIC_AUTH_FILE"
