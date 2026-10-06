#!/bin/sh

# ./create-gateway-client-auth.sh -a "plain|oauth|scram" -f "/path/to/creds" -n "namespace" -c
# creds file should be username:password per line

BASE_DIR=$(pwd)
GEN_DIR="$BASE_DIR/generated/creds/gateway/client"
AUTH_TYPE=""
CREDS_PATH=""
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
    printf "Usage: $0 [-a] [string] [-f] [string] [-n] [string] [-c]\n"
    printf "\t-a plain|oauth|scram              (required) client auth type\n"
    printf "\t-f path                           (required) Only required when auth_type is plain or scram\n"
    printf "\t-n namespace                      (required) kubernetes namesapce to use in script, e.g. confluent\n"
    printf "\t-c                                (optional) clean deployment\n"
    exit 1
}

while getopts "a:f:n:c" opt; do
    case $opt in
        a)
            AUTH_TYPE=$OPTARG
            ;;
        f)
            CREDS_PATH=$OPTARG
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
if [ -z "$AUTH_TYPE" ] || [ -z "$NAMESPACE" ]; then
    printf "Error: $0 requires arguments\n"
    usage
fi

# check if credential file is needed
if [ "$AUTH_TYPE" == "plain" ] || [ "$AUTH_TYPE" == "scram" ]; then
    if [ -z "$CREDS_PATH" ]; then
        printf "Error: Auth Type of %s, requires a credential file\n" "$AUTH_TYPE"
        usage
    fi
fi

generate_assets () {

    # SASL/PLAIN authentication 
    if [ "$AUTH_TYPE" == "plain" ]; then

        mkdir -p "$GEN_DIR/files/plain"
        echo "{}" > "$GEN_DIR/files/plain/plain-users.json"
        echo "{}" > "$GEN_DIR/files/plain/plain-users.json.tmp"
        printf "org.apache.kafka.common.security.plain.PlainLoginModule required" > "$GEN_DIR/files/plain/plain-jaas.conf"

        while IFS=':' read -r gateway_user gateway_pass; do
            # uncomment for debug
            #printf "Gateway User: %s\nGateway Pass: %s\n" "$gateway_user" "$gateway_pass"
            # append to json
            jq --arg KEY "$gateway_user" --arg VALUE "$gateway_pass" '.[$KEY] = $VALUE' "$GEN_DIR/files/plain/plain-users.json" > "$GEN_DIR/files/plain/plain-users.json.tmp" && cp "$GEN_DIR/files/plain/plain-users.json.tmp" "$GEN_DIR/files/plain/plain-users.json"
            # append to jaas
            printf "\n\tuser_%s=\"%s\"" "$gateway_user" "$gateway_pass" >> "$GEN_DIR/files/plain/plain-jaas.conf"

        done < "$CREDS_PATH"

        printf ";\n" >> "$GEN_DIR/files/plain/plain-jaas.conf"

        # tmp file cleanup
        rm "$GEN_DIR/files/plain/plain-users.json.tmp"
    fi
}

generate_bash_script () {

    auth_type=$1
    file_type=$2
    if [ "$auth_type" == "plain" ]; then
        file_name="create-gateway-client-plain-$file_type-secret.sh"
        secret_name="gateway-client-p$file_type"
    elif [ "$auth_type" == "oauth" ]; then
        file_name="create-gateway-client-oauth-jaas-secret.sh"
        secret_name="gateway-client-ojaas"
    elif [ "$auth_type" == "scram" ]; then
        file_name="create-gateway-client-scram-admin-secret.sh"
        secret_name="gateway-client-scram-admin"
    else
        printf "Error: Auth Type is not known: %s, exiting...\n" "$auth_type"
        exit 1
    fi

    cmd="-n \$NAMESPACE create secret generic $secret_name"
    gen_path="$GEN_DIR/cmd/$file_name"

    if [ "$auth_type" == "plain" ]; then
        if [ "$file_type" == "json" ]; then
            cmd+=" --from-file=plain-users.json=$GEN_DIR/files/plain/plain-users.json"
        elif [ "$file_type" == "jaas" ]; then
            cmd+=" --from-file=plain-jaas.conf=$GEN_DIR/files/plain/plain-jaas.conf"
        else
            printf "SASL/PLAIN File type not recognized: %s, exiting...\n" "$file_type"
            exit 1
        fi

    elif [ "$auth_type" == "oauth" ]; then
        # NOTE: CFK Operator expects oauth-jass.conf instead of oauth-jaas.conf, seems like a bug
        cmd+=" --from-literal=oauth-jass.conf='org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;'"
    elif [ "$auth_type" == "scram" ]; then
        if [ -f "$CREDS_PATH" ]; then
            l_username=$(head -n 1 $CREDS_PATH | awk -F ":" '{ printf $1 }')
            l_password=$(head -n 1 $CREDS_PATH | awk -F ":" '{ printf $2 }')

            cmd+=" --from-literal=username=$l_username"
            cmd+=" --from-literal=password=$l_password"
        else
            printf "Credentials file is invalid, exiting...\n"
            exit 1
        fi
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

    if [ "$auth_type" == "plain" ]; then
        printf "\nCreated Gateway Client %s-%s secret bash script at %s\n" "$auth_type" "$file_type" "$gen_path"
    else
        printf "\nCreated Gateway Client %s secret bash script at %s\n" "$auth_type" "$gen_path"
    fi

}

source $BASE_DIR/scripts/system/header.sh -t "Generating Gateway Client Credentials"

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
printf "\n\tClient Auth Type = %s\n" "$AUTH_TYPE"
if [ "$AUTH_TYPE" == "plain" ]; then
    generate_assets
    generate_bash_script "$AUTH_TYPE" "json"
    generate_bash_script "$AUTH_TYPE" "jaas"
else
    generate_bash_script "$AUTH_TYPE"
fi
