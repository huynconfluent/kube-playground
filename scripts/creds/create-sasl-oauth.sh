#!/bin/sh

# ./create-sasl-oauth.sh -n "namespace" -u "user_json" -c

BASE_DIR=$(pwd)
GEN_DIR="$BASE_DIR/generated/creds/oauth"
TXT_GEN_DIR="$GEN_DIR/files/txt"
JAAS_GEN_DIR="$GEN_DIR/files/jaas"
CMD_GEN_DIR="$GEN_DIR/cmd"
OPTIND=1
SCOPE_ENABLED=false
MDS_ENABLED=false
TRUSTSTORE_ENABLED=false
DEPLOY_CLEAN=false
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
    printf "Usage: $0 [-u] [string] [-n] [string] [-m] [string] [-t] [string] [-p] [string] [-s] [string] [-c]\n"
    printf "\t-u [path_to_json]                 (required) user json file\n"
    printf "\t-m [path_to_pem]                  (optional) MDS Public Key\n"
    printf "\t-t [path_to_pem]                  (optional) IDP Truststore Location\n"
    printf "\t-p [string]                       (optional) IDP Truststore Password (required if Truststore Location is specified)\n"
    printf "\t-s [string]                       (optional) Scope\n"
    printf "\t-n namespace                      (required) kubernetes namesapce to use in script, e.g. confluent\n"
    printf "\t-c                                (optional) clean deployment\n"
    exit 1
}

while getopts "u:n:cm:t:p:s:" opt; do
    case $opt in
        u)
            USER_JSON=$OPTARG
            # validation checking
            if ! jq -e . $USER_JSON > /dev/null 2>&1; then
               printf "JSON file is invalid, exiting...\n"
               exit 1
            fi
            ;;
        m)
            MDS_ENABLED=true
            MDS_PUBLIC_KEY=$OPTARG
            ;;
        t)
            TRUSTSTORE_ENABLED=true
            TRUSTSTORE_LOCATION=$OPTARG
            ;;
        p)
            TRUSTSTORE_PASSWORD=$OPTARG
            ;;
        s)
            SCOPE_ENABLED=true
            SCOPE=$OPTARG
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

if [ "$SCOPE_ENABLED" == "true" ]; then
    if [ -z "$SCOPE" ]; then
        printf "Error: scope cannot be empty\n"
        usage
    fi
fi

if [ "$MDS_ENABLED" == "true" ]; then
    if [ -z "$MDS_PUBLIC_KEY" ]; then
        printf "Error: MDS Public Key cannot be empty\n"
        usage
    fi
fi

if [ "$TRUSTSTORE_ENABLED" == "true" ]; then
    if [ -z "$TRUSTSTORE_LOCATION" ] || [ -z "$TRUSTSTORE_PASSWORD" ]; then
        printf "Error: Truststore Location or Password cannot be empty\n"
        usage
    fi
fi

generate_bash_script () {

    secret_raw=$2

    if [ "$1" == "txt" ]; then
        secret_name="otxt-$secret_raw"
        file_key="oauth.txt"
        file_name="create-sasl-oauth-txt-$secret_raw-secret.sh"
    elif [ "$1" == "jaas" ]; then
        secret_name="ojaas-$secret_raw"
        file_key="oauth-jaas.conf"
        file_name="create-sasl-oauth-jaas-$secret_raw-secret.sh"
    else
        printf "Unknown argument...\n"
        exit 1
    fi

    file_path=$3

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

generate_jaas_files() {

    l_clientid=$1
    l_clientsecret=$2
    file_name="$JAAS_GEN_DIR/$l_clientid-oauth-jaas.conf"

    # create oauth-jaas.conf for jaasConfigPassthrough
    printf "sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required \\" > "$file_name"
    printf "\n\tclientId=\"%s\" \\" "$l_clientid" >> "$file_name"
    printf "\n\tclientSecret=\"%s\"" "$l_clientsecret" >> "$file_name"
    # https://docs.confluent.io/platform/7.5/kafka/authentication_sasl/authentication_sasl_oauth.html#unsecured-client-side-token-creation-options-for-sasl-oauthbearer
    # https://docs.confluent.io/platform/8.1/security/authentication/sasl/oauthbearer/configure-clients.html#example-using-kafka-console-consumer-with-sasl-oauthbearer
    if [ "$l_clientid" == "kafkabroker" ] || [ "$l_clientid" == "kafkacontroller" ]; then
        # optional unsecuredLoginStringClaim_sub (required for inter broker)
        printf " \\" >> "$file_name"
        printf "\n\tunsecuredLoginStringClaim_sub=\"%s\"" "$l_clientid" >> "$file_name"
        # optional publicKeyPath
        if [ "$MDS_ENABLED" == "true" ]; then
            printf " \\" >> "$file_name"
            printf "\n\tpublicKeyPath=\"%s\"" "$MDS_PUBLIC_KEY" >> "$file_name"
        fi
    fi
    # optional scope
    if [ "$SCOPE_ENABLED" == "true" ]; then
        printf " \\" >> "$file_name"
        printf "\n\tscope=\"%s\"" "$l_clientid" >> "$file_name"
    fi
    # optional ssl truststore for IDPs using self-signed certs
    if [ "$TRUSTSTORE_ENABLED" == "true" ]; then
        printf " \\" >> "$file_name"
        printf "\n\tssl.truststore.location=\"%s\" \\" "$TRUSTSTORE_LOCATION" >> "$file_name"
        printf "\n\tssl.truststore.password=\"%s\"" "$TRUSTSTORE_PASSWORD" >> "$file_name"
    fi
     
    # let's close the loop
    printf ";\n" >> "$file_name"

    # generate kubectl command for oauth-jaas.conf
    generate_bash_script "jaas" "$l_clientid" "$file_name"
}

generate_txt_files() {

    l_clientid=$1
    l_clientsecret=$2

    # generate client oauth.txt (used for jaasConfig bearer and oauthbearer auth in CFK)
    printf "clientId=%s\nclientSecret=%s\n" "$l_clientid" "$l_clientsecret" > "$TXT_GEN_DIR/$l_clientid-oauth.txt"

    # generate kubectl command for oauth.txt
    generate_bash_script "txt" "$l_clientid" "$TXT_GEN_DIR/$l_clientid-oauth.txt"
}

source $BASE_DIR/scripts/system/header.sh -t "Generating SASL/OAUTHBEARER Credentials"

# remove generated files?
if [[ "$DEPLOY_CLEAN" == "true" ]]; then
    printf "Deleting generated files...\n"
    if [ -d "$GEN_DIR" ]; then
        rm -r "$GEN_DIR"
    else
        printf "Directory doesn't exist, skipping...\n"
    fi
fi

if [ ! -d "$CMD_GEN_DIR" ]; then
    mkdir -p "$CMD_GEN_DIR"
fi

if [ ! -d "$TXT_GEN_DIR" ]; then
    mkdir -p "$TXT_GEN_DIR"
fi

if [ ! -d "$JAAS_GEN_DIR" ]; then
    mkdir -p "$JAAS_GEN_DIR"
fi

# read in json, first user is considered admin
printf "Path to user json file: %s\n" "$USER_JSON"

# using keys_unsorted to keey ordering found in JSON file
USER_DATA=( $(cat $USER_JSON | jq -r 'keys_unsorted[]' ) )

# loop through users and generate files
printf "Creating Client-side files...\n"
for client_id in "${USER_DATA[@]}"; do
    # determine user password
    client_secret=$(cat $USER_JSON | jq -r .[\"${client_id}\"])
    # generate oauth.txt
    generate_txt_files "$client_id" "$client_secret"
    # generate oauth-jaas.conf
    generate_jaas_files "$client_id" "$client_secret"
done

source $BASE_DIR/scripts/system/header.sh -t "Completed Generating SASL/OAUTHBEARER Credentials"
