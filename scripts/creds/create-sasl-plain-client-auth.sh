#!/bin/sh

# ./create-sasl-plain-client-auth.sh -n "namespace" -u "/full/path/to/plain-users.json"

BASE_DIR=$(pwd)
GEN_DIR="$BASE_DIR/generated/creds/sasl-plain"
CLIENT_GEN_DIR="$GEN_DIR/client-side/files"
CMD_GEN_DIR="$GEN_DIR/client-side/cmd"
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
    printf "Usage: $0 [-u] [string] [-n] [string]\n"
    printf "\t-u [path_to_json]                 (required) user json file\n"
    printf "\t-n namespace                      (required) kubernetes namesapce to use in script, e.g. confluent\n"
    printf "\t-c                                (optional) clean deployment\n"
    exit 1
}

while getopts "u:n:c" opt; do
    case $opt in
        u)
            USER_JSON=$OPTARG
            # validation checking
            if ! jq -e . $USER_JSON > /dev/null 2>&1; then
               printf "JSON file is invalid, exiting...\n"
               exit 1
            fi
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
if [ -z "$USER_JSON" ] || [ -z "$NAMESPACE" ]; then
    printf "Error: $0 requires arguments\n"
    usage
fi

generate_client_bash_script () {

    username=$1
    file_key=$2
    file_path=$3
    if [ "$file_key" == "plain.txt" ]; then
        secret_name="ptxt-$1"
        file_name="create-client-sasl-plain-txt-$username-secret.sh"
    else
        secret_name="pjaas-$1"
        file_name="create-client-sasl-plain-jaas-$username-secret.sh"
    fi
    cmd="-n \$NAMESPACE create secret generic $secret_name --from-file=$file_key=$file_path"
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

generate_client_files() {

    username="$1"
    password="$2"

    # generate client plain.txt
    printf "username=%s\npassword=%s\n" "$username" "$password" > "$CLIENT_GEN_DIR/$username-plain.txt"
    
    # generate kubectl command
    generate_client_bash_script "$username" "plain.txt" "$CLIENT_GEN_DIR/$username-plain.txt"

    # generate client plain-jaas.conf
    printf "sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \\" > "$CLIENT_GEN_DIR/$username-plain-jaas.conf"
    printf "\n\tusername=\"%s\" \\" "$username" >> "$CLIENT_GEN_DIR/$username-plain-jaas.conf"
    printf "\n\tpassword=\"%s\";\n" "$password" >> "$CLIENT_GEN_DIR/$username-plain-jaas.conf"

    generate_client_bash_script "$username" "plain-jaas.conf" "$CLIENT_GEN_DIR/$username-plain-jaas.conf"

}

source $BASE_DIR/scripts/system/header.sh -t "Generating SASL/PLAIN Credentials"

# remove generated files?
if [[ "$DEPLOY_CLEAN" == "true" ]]; then
    printf "Deleting generated files...\n"
    if [ -d "$GEN_DIR/client-side" ]; then
        rm -r "$GEN_DIR/client-side"
    else
        printf "Directory doesn't exist, skipping...\n"
    fi
fi

if [ ! -d "$CMD_GEN_DIR" ]; then
    mkdir -p "$CMD_GEN_DIR"
fi
if [ ! -d "$CLIENT_GEN_DIR" ]; then
    mkdir -p "$CLIENT_GEN_DIR"
fi

# read in json, first user is considered admin
printf "Path to user json file: %s\n" "$USER_JSON"

# using keys_unsorted to keep ordering found in JSON file
USER_DATA=( $(cat $USER_JSON | jq -r 'keys_unsorted[]' ) )

# loop through users and generate files
printf "Creating Client-side files...\n"
for user in "${USER_DATA[@]}"; do
    # determine user password
    user_password=$(cat $USER_JSON | jq -r .[\"${user}\"])
    generate_client_files "$user" "$user_password"
done

source $BASE_DIR/scripts/system/header.sh -t "Completed Generating SASL/PLAIN Credentials"
