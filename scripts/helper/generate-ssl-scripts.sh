#!/bin/sh

# ./generate-ssl-scripts.sh <component> <gen_dir> <namespace> <fullchain> <privkey> <cacerts>
# ./generate-ssl-scripts.sh -c <component> -d <gen_dir> -n <namespace> -f <fullchain> -p <privkey> -a <cacerts>
#

HOME_DIR=$(pwd)
# reset
OPTIND=1
set -o allexport; source .env; set +o allexport

# flags
usage () {
    printf "Usage: $0 [-c] [string] [-d] [path] [-n] [string] [-f] [path] [-p] [path] [-a] [path] \n"
    printf "\t-c component_name                 (required) component name, e.g. kafka\n"
    printf "\t-d directory                      (required) output directory, e.g. full path\n"
    printf "\t-n namespace                      (required) kubernetes namesapce to use in script, e.g. confluent\n"
    printf "\t-f fullchain.pem                  (required) fullchain PEM file for the component\n"
    printf "\t-p private.key                    (required) private key in PEM format for the component\n"
    printf "\t-a cacerts.pem                    (required) cacerts PEM file\n"
    exit 1
}

while getopts "c:d:n:f:p:a:" opt; do
    case $opt in
        c)
            COMPONENT=$OPTARG
            ;;
        d)
            GEN_DIR=$OPTARG
            GEN_DIR_SSL_CMD="$GEN_DIR/cmd"
            ;;
        n)
            NAMESPACE=$OPTARG
            ;;
        f)
            FULLCHAIN_PATH=$OPTARG
            ;;
        p)
            PRIVKEY_PATH=$OPTARG
            ;;
        a)
            CACERTS_PATH=$OPTARG
            ;;
        *)
            usage
            ;;
    esac
done

# ensure input has value
if [ -z "$COMPONENT" ] || [ -z "$GEN_DIR" ] || [ -z "$NAMESPACE" ] || [ -z "$FULLCHAIN_PATH" ] || [ -z "$CACERTS_PATH" ] || [ -z "$PRIVKEY_PATH" ]; then
    printf "Error: $0 requires arguments\n"
    usage
fi


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
    
    cmd="-n \$NAMESPACE create secret generic tls-$COMPONENT --from-file=fullchain.pem=$FULLCHAIN_PATH --from-file=cacerts.pem=$CACERTS_PATH --from-file=privkey.pem=$PRIVKEY_PATH"
    file_name="create-tls-$COMPONENT-secret.sh"
    
    # uncomment to debug
    #printf "\nKubectl Command: eval kubectl|oc %s\n" "$cmd"

    # Create cmd direcotry for component
    if [ ! -d "$GEN_DIR_SSL_CMD/$COMPONENT" ]; then
        printf "\nMaking Command directory in %s...\n" "$GEN_DIR_SSL_CMD/$COMPONENT"
        mkdir -p "$GEN_DIR_SSL_CMD/$COMPONENT"
    fi

    printf "#!/bin/sh\n\n" > $GEN_DIR_SSL_CMD/$COMPONENT/$file_name
    printf "# ./$file_name [kubectl|oc] [namespace]\n\n" >> $GEN_DIR_SSL_CMD/$COMPONENT/$file_name
    printf "KCMD=\${1:-kubectl}\n" >> $GEN_DIR_SSL_CMD/$COMPONENT/$file_name
    printf "NAMESPACE=\${2:-%s}\n" "$NAMESPACE" >> $GEN_DIR_SSL_CMD/$COMPONENT/$file_name
    printf "eval \"\$KCMD %s\"\n" "$cmd" >> $GEN_DIR_SSL_CMD/$COMPONENT/$file_name
    chmod +x "$GEN_DIR_SSL_CMD/$COMPONENT/$file_name"

    printf "Created bash script at %s\n" "$GEN_DIR_SSL_CMD/$COMPONENT/$file_name"
}

generate_bash_script
