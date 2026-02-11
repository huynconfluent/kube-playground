#!/bin/sh

# ./generate-ssl-jks-scripts.sh <component> <gen_dir> <namespace> <fullchain> <privkey> <cacerts>
# ./generate-ssl-jks-scripts.sh -c <component> -d <gen_dir> -n <namespace> -f <fullchain> -p <privkey> -a <cacerts>
#

BASE_DIR=$(pwd)
# reset
OPTIND=1
set -o allexport; source .env; set +o allexport

# flags
usage () {
    printf "Usage: $0 [-c] [string] [-d] [path] [-n] [string] [-k] [path] [-t] [path] [-p] [path] \n"
    printf "\t-c component_name                 (required) component name, e.g. kafka\n"
    printf "\t-d directory                      (required) output directory, e.g. full path\n"
    printf "\t-n namespace                      (required) kubernetes namesapce to use in script, e.g. confluent\n"
    printf "\t-k keystore.jks                   (required) keystore.jks file\n"
    printf "\t-t truststore.jks                 (required) truststore.jks file\n"
    printf "\t-p jksPassword.txt                (required) jksPassword.txt file\n"
    exit 1
}

while getopts "c:d:n:k:t:p:" opt; do
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
        k)
            KEYSTORE_PATH=$OPTARG
            ;;
        t)
            TRUSTSTORE_PATH=$OPTARG
            ;;
        p)
            PASSWORD_PATH=$OPTARG
            ;;
        *)
            usage
            ;;
    esac
done

# ensure input has value
if [ -z "$COMPONENT" ] || [ -z "$GEN_DIR" ] || [ -z "$NAMESPACE" ] || [ -z "$KEYSTORE_PATH" ] || [ -z "$TRUSTSTORE_PATH" ] || [ -z "$PASSWORD_PATH" ]; then
    printf "Error: $0 requires arguments\n"
    usage
fi


if [ ! -d "$GEN_DIR" ]; then
    printf "\nGenerated Directory Path UNKNOWN...."
    printf "\nPath: %s\n" "$GEN_DIR"
    exit 1
fi

if [[ ! -f "$KEYSTORE_PATH" ]] || [[ ! -f "$TRUSTSTORE_PATH" ]] || [[ ! -f "$PASSWORD_PATH" ]]; then
    printf "\nMissing Certificate File..."
    printf "\nKEYSTORE_PATH: %s" "$KEYSTORE_PATH"
    printf "\nTRUSTSTORE_PATH: %s" "$TRUSTSTORE_PATH"
    printf "\nPASSWORD_PATH: %s\n" "$PASSWORD_PATH" 
    exit 1
fi

generate_bash_script () {
    
    cmd="-n \$NAMESPACE create secret generic jks-$COMPONENT --from-file=keystore.jks=$KEYSTORE_PATH --from-file=truststore.jks=$TRUSTSTORE_PATH --from-file=jksPassword.txt=$PASSWORD_PATH"
    file_name="create-jks-$COMPONENT-secret.sh"
    
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
