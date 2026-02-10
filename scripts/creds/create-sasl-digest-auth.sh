#!/bin/sh

# ./create-sasl-digest-auth.sh -n "namespace" -u "/full/path/to/digest-users.json" -c

BASE_DIR=$(pwd)
GEN_DIR="$BASE_DIR/generated/creds/sasl-digest"
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
    printf "Usage: $0 [-u] [string] [-n] [string]\n"
    printf "\t-u json file                      (required) json file of users\n"
    printf "\t-n namespace                      (required) kubernetes namesapce to use in script, e.g. confluent\n"
    printf "\t-c                                (optional) clean deployment\n"
    exit 1
}

while getopts "u:n:c" opt; do
    case $opt in
        u)
            USER_JSON=$OPTARG
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

# for client
generate_server_bash_script () {

    file_path="$2"
    if [ "$1" == "json" ]; then
        file_key="digest-users.json"
        secret_name="digest-zookeeper-server-json"
        file_name="create-digest-server-zookeeper-json-secret.sh"
    else
        file_key="digest-jaas.conf"
        secret_name="digest-zookeeper-server-jaas"
        file_name="create-digest-server-zookeeper-jaas-secret.sh"
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

generate_client_bash_script () {

    username="$1"
    txt_file_path="$2"
    jaas_file_path="$3"

    # create txt secret
    cmd="-n \$NAMESPACE create secret generic digest-$username-txt --from-file=digest.txt=$txt_file_path"
    file_name="create-digest-client-$username-txt-secret.sh"
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

    # create jaas secret
    cmd="-n \$NAMESPACE create secret generic digest-$username-jaas --from-file=digest-jaas.conf=$jaas_file_path"
    file_name="create-digest-client-$username-jaas-secret.sh"
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

    usersJson=$1
    userList=( $(cat $usersJson | jq -r 'keys_unsorted[]' ) )
    username="${userList[0]}"
    password=$(cat $usersJson | jq -r .[\"${userList[0]}\"])
    digest_conf="$SERVER_GEN_DIR/digest-jaas.conf"

    if [ ! -f "$SERVER_GEN_DIR/digest-users.json" ]; then
        printf "Copying provided digest-users.json to generated directory...\n"
        cp "$USER_JSON" "$SERVER_GEN_DIR/digest-users.json"
    fi

    if [ -f "$SERVER_GEN_DIR/digest-users.json" ]; then
        # generate our server side json secret
        printf "Calling bash script generator for diget-users.json...\n"
        generate_server_bash_script "json" "$SERVER_GEN_DIR/digest-users.json"
    else
        printf "There was a problem with %s...\n" "$SERVER_GEN_DIR/digest-users.json"
        exit 1
    fi

    # create digest-jaas.conf for jaasConfigPassthrough
    printf "Server {\n" > "$digest_conf"
    printf "\torg.apache.zookeeper.server.auth.DigestLoginModule required" >> $digest_conf
     
    # loop through the users
    if [[ "${#userList[@]}" -gt 1 ]]; then
        # starting index
        index=0
        for user in "${userList[@]}"; do
            userPass=$(cat $usersJson | jq -r .[\"${user}\"])
            printf " \\n\tuser_%s=\"%s\"" "$user" "$userPass" >> $digest_conf
            #if [[ "$index" -lt "${#userList[@]}" ]]; then
            #  printf " \\" >> $digest_conf
            #fi
            ((index++))
        done
    fi
    
    # let's close the loop
    printf ";\n};\n" >> $digest_conf

    # QuorumServer
    printf "\n" >> $digest_conf
    printf "QuorumServer {\n\torg.apache.zookeeper.server.auth.DigestLoginModule required\n" >> $digest_conf
    printf "\tuser_%s=\"%s\";\n};\n" "$username" "$password" >> $digest_conf
    # QuorumLearner
    printf "\nQuorumLearner {\n\torg.apache.zookeeper.server.auth.DigestLoginModule required\n" >> $digest_conf
    printf "\tuser=\"%s\"\n\tpassword=\"%s\";\n};\n" "$username" "$password" >> $digest_conf

    # create command for
    printf "Calling bash script generator for digest-jaas.conf...\n"
    generate_server_bash_script "jaas" "$SERVER_GEN_DIR/digest-users.json"
}

generate_client_files() {

    username="$1"
    password="$2"
    digest_file_name="$username-digest.txt"
    jaas_file_name="$username-jaas.conf"


    # generate client digest.txt
    printf "Generating digest.txt for %s\n" "$username"
    printf "username=%s\npassword=%s\n" "$username" "$password" > $CLIENT_GEN_DIR/$digest_file_name

    # generate client digest-jaas.conf
    printf "Generating digest-jaas.conf for %s\n" "$username"
    printf "Client {\n\torg.apache.zookeeper.server.auth.DigestLoginModule required\n\tusername=\"%s\"\n\tpassword=\"%s\";\n};\n" "$username" "$password" > $CLIENT_GEN_DIR/$jaas_file_name

    printf "Calling bash script generator...\n"
    generate_client_bash_script "$username" "$CLIENT_GEN_DIR/$digest_file_name" "$CLIENT_GEN_DIR/$jaas_file_name"
}

source $BASE_DIR/scripts/system/header.sh -t "Generating SASL/DIGEST Credentials"

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
    mkdir -p "$CMD_GEN_DIR"
fi
if [ ! -d "$SERVER_GEN_DIR" ]; then
    mkdir -p "$SERVER_GEN_DIR"
fi
if [ ! -d "$CLIENT_GEN_DIR" ]; then
    mkdir -p "$CLIENT_GEN_DIR"
fi

# read in digest-users.json file
#printf "Path to user json file: %s\n" "$USER_JSON"

# using keys_unsorted to keey ordering found in JSON file
USER_LIST=( $(cat $USER_JSON | jq -r 'keys_unsorted[]' ) )

# create server files
generate_server_files "$USER_JSON"

printf "Creating credentials for client users from JSON file...\n"
# loop through users and generate files
for user in "${USER_LIST[@]}"; do
    userPass=$(cat $USER_JSON | jq -r .[\"${user}\"])
    generate_client_files "$user" "$userPass"
done

source $BASE_DIR/scripts/system/header.sh -t "SASL/DIGEST Credentials Completed!"
