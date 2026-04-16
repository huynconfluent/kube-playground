#!/bin/sh

# ./create-sasl-plain-auth.sh -n "namespace" -u "/full/path/to/plain-users.json" -i "interbroker_user:interbroker_password"

BASE_DIR=$(pwd)
GEN_DIR="$BASE_DIR/generated/creds/sasl-plain"
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
    printf "Usage: $0 [-u] [string] [-i] [string:string] [-n] [string]\n"
    printf "\t-u [path_to_json]                 (required) user json file\n"
    printf "\t-i [string:string]                (required) interbroker username:password\n"
    printf "\t-n namespace                      (required) kubernetes namesapce to use in script, e.g. confluent\n"
    printf "\t-c                                (optional) clean deployment\n"
    exit 1
}

while getopts "u:i:n:c" opt; do
    case $opt in
        u)
            USER_JSON=$OPTARG
            # validation checking
            if ! jq -e . $USER_JSON > /dev/null 2>&1; then
               printf "JSON file is invalid, exiting...\n"
               exit 1
            fi
            ;;
        i)
            INTER_USER=$(echo $OPTARG | awk -F ':' '{printf $1}')
            INTER_PASSWORD=$(echo $OPTARG | awk -F ':' '{printf $2}')
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
if [ -z "$USER_JSON" ] || [ -z "$NAMESPACE" ] || [ -z "$INTER_USER" ] || [ -z "$INTER_PASSWORD" ]; then
    printf "Error: $0 requires arguments\n"
    usage
fi

generate_client_bash_script () {

    secret_name="plain-$1"
    file_key=$2
    file_path=$3
    cmd="-n \$NAMESPACE create secret generic $secret_name --from-file=$file_key=$file_path"
    if [ "$file_key" == "plain.txt" ]; then
        file_name="create-client-sasl-plain-txt-$secret_name-secret.sh"
    else
        file_name="create-client-sasl-plain-jaas-$secret_name-secret.sh"
    fi
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

generate_server_files() {

    # copy input file to generated directory
    cp "$USER_JSON" "$SERVER_GEN_DIR/plain-users.json"
    user_list=( $(cat $SERVER_GEN_DIR/plain-users.json | jq -r 'keys_unsorted[]' ) )

    # create plain-interbroker.txt
    printf "username=%s\npassword=%s\n" "$INTER_USER" "$INTER_PASSWORD" > "$SERVER_GEN_DIR/plain-interbroker.txt"

    # create plain-jaas.conf
    printf "sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \\" > "$SERVER_GEN_DIR/plain-jaas.conf"
    printf "\n\tusername=\"%s\" \\" "$INTER_USER" >> "$SERVER_GEN_DIR/plain-jaas.conf"
    printf "\n\tpassword=\"%s\" \\" "$INTER_PASSWORD" >> "$SERVER_GEN_DIR/plain-jaas.conf"

    # if we have additional users, loop through and add them
    if [[ "${#user_list[@]}" -gt 1 ]]; then
        index=0
        for user in "${user_list[@]}"; do
            user_password=$(cat $SERVER_GEN_DIR/plain-users.json | jq -r .[\"${user}\"])
            printf " \\n\tuser_%s=\"%s\"" "$user" "$user_password" >> $SERVER_GEN_DIR/plain-jaas.conf
            if [[ "$index" -lt "${#user_list[@]} -1" ]]; then
                printf " \\" >> "$SERVER_GEN_DIR/plain-jaas.conf"  
            fi
            ((index++))
        done
    fi

    # let's close the loop
    printf ";\n" >> $SERVER_GEN_DIR/plain-jaas.conf


    # create plain-users.json+plain-interbroker.txt
    cmd="-n \$NAMESPACE create secret generic server-sasl-plain-creds --from-file=plain-users.json=$SERVER_GEN_DIR/plain-users.json --from-file=plain-interbroker.txt=$SERVER_GEN_DIR/plain-interbroker.txt"
    file_name="create-server-sasl-plain-creds-secret.sh"
    gen_path="$CMD_GEN_DIR/$file_name"

    # uncomment to debug
    #printf "\nKubectl Command: eval kubectl|oc %s\n" "$cmd"

    printf "#!/bin/sh\n\n" > $gen_path
    printf "# ./$file_name [kubectl|oc] [namespace]\n\n" >> $gen_path
    printf "KCMD=\${1:-kubectl}\n" >> $gen_path
    printf "NAMESPACE=\${2:-%s}\n" "$NAMESPACE" >> $gen_path
    printf "eval \"\$KCMD %s\"\n" "$cmd" >> $gen_path
    chmod +x "$gen_path"

    printf "Created bash script for server-sasl-plain-creds at %s\n" "$gen_path"

    # create plain-jaas.conf
    cmd="-n \$NAMESPACE create secret generic server-sasl-plain-jaas --from-file=plain-users.json=$SERVER_GEN_DIR/plain-users.json --from-file=plain-interbroker.txt=$SERVER_GEN_DIR/plain-interbroker.txt"
    file_name="create-server-sasl-plain-jaas-secret.sh"
    gen_path="$CMD_GEN_DIR/$file_name"

    # uncomment to debug
    #printf "\nKubectl Command: eval kubectl|oc %s\n" "$cmd"

    printf "#!/bin/sh\n\n" > $gen_path
    printf "# ./$file_name [kubectl|oc] [namespace]\n\n" >> $gen_path
    printf "KCMD=\${1:-kubectl}\n" >> $gen_path
    printf "NAMESPACE=\${2:-%s}\n" "$NAMESPACE" >> $gen_path
    printf "eval \"\$KCMD %s\"\n" "$cmd" >> $gen_path
    chmod +x "$gen_path"

    printf "Created bash script for server-sasl-plain-jaas at %s\n" "$gen_path"
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
    if [ -d "$GEN_DIR" ]; then
        rm -r "$GEN_DIR"
    else
        printf "Directory doesn't exist, skipping...\n"
    fi
fi

if [ ! -d "$GEN_DIR/cmd" ]; then
    mkdir -p "$GEN_DIR/cmd"
fi
if [ ! -d "$SERVER_GEN_DIR" ]; then
    mkdir -p "$SERVER_GEN_DIR"
fi
if [ ! -d "$CLIENT_GEN_DIR" ]; then
    mkdir -p "$CLIENT_GEN_DIR"
fi

# read in json, first user is considered admin
printf "Path to user json file: %s\n" "$USER_JSON"

# using keys_unsorted to keey ordering found in JSON file
USER_DATA=( $(cat $USER_JSON | jq -r 'keys_unsorted[]' ) )

# create server files
printf "Creating Server-side files...\n"
generate_server_files

# loop through users and generate files
printf "Creating Client-side files...\n"
for user in "${USER_DATA[@]}"; do
    # determine user password
    user_password=$(cat $USER_JSON | jq -r .[\"${user}\"])
    generate_client_files "$user" "$user_password"
done

source $BASE_DIR/scripts/system/header.sh -t "Completed Generating SASL/PLAIN Credentials"
