#!/bin/sh

# ./generate-ssl-bcfks-scripts.sh -c <component_name> -d <output_dir> -n <namespace> -k <keystore.jks> -t <truststore.jks> -p <keystore_and_truststore_password> -b <keystore.bcfks> -r <truststore.bcfks>

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
    printf "\t-b keystore.bcfks                 (required) keystore.bcfks file\n"
    printf "\t-r truststore.bcfks               (required) truststore.bcfks file\n"
    printf "\t-p jksPassword.txt                (required) jksPassword.txt file\n"
    exit 1
}

while getopts "c:d:n:k:t:p:b:r:" opt; do
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
            JKS_KEYSTORE_PATH=$OPTARG
            ;;
        t)
            JKS_TRUSTSTORE_PATH=$OPTARG
            ;;
        p)
            PASSWORD_PATH=$OPTARG
            ;;
        b)
            BCFKS_KEYSTORE_PATH=$OPTARG
            ;;
        r)
            BCFKS_TRUSTSTORE_PATH=$OPTARG
            ;;
        *)
            usage
            ;;
    esac
done

# ensure input has value
if [ -z "$COMPONENT" ] || [ -z "$GEN_DIR" ] || [ -z "$NAMESPACE" ] || [ -z "$JKS_KEYSTORE_PATH" ] || [ -z "$JKS_TRUSTSTORE_PATH" ] || [ -z "$PASSWORD_PATH" ] || [ -z "$BCFKS_KEYSTORE_PATH" ] || [ -z "$BCFKS_TRUSTSTORE_PATH" ]; then
    printf "Error: $0 requires arguments\n"
    usage
fi


if [ ! -d "$GEN_DIR" ]; then
    printf "\nGenerated Directory Path UNKNOWN...."
    printf "\nPath: %s\n" "$GEN_DIR"
    exit 1
fi

if [[ ! -f "$JKS_KEYSTORE_PATH" ]] || [[ ! -f "$JKS_TRUSTSTORE_PATH" ]] || [[ ! -f "$PASSWORD_PATH" ]] || [[ ! -f "$BCFKS_KEYSTORE_PATH" ]] || [[ ! -f "$BCFKS_TRUSTSTORE_PATH" ]]; then
    printf "\nMissing Certificate File..."
    printf "\nJKS_KEYSTORE_PATH: %s" "$JKS_KEYSTORE_PATH"
    printf "\nJKS_TRUSTSTORE_PATH: %s" "$JKS_TRUSTSTORE_PATH"
    printf "\nBCFKS_KEYSTORE_PATH: %s" "$BCFKS_KEYSTORE_PATH"
    printf "\nBCFKS_TRUSTSTORE_PATH: %s" "$BCFKS_TRUSTSTORE_PATH"
    printf "\nPASSWORD_PATH: %s\n" "$PASSWORD_PATH" 
    exit 1
fi

generate_bash_script () {
    
    cmd="-n \$NAMESPACE create secret generic bcfks-$COMPONENT --from-file=keystore.jks=$JKS_KEYSTORE_PATH --from-file=truststore.jks=$JKS_TRUSTSTORE_PATH --from-file=keystore.bcfks=$BCFKS_KEYSTORE_PATH --from-file=truststore.bcfks=$BCFKS_TRUSTSTORE_PATH --from-file=jksPassword.txt=$PASSWORD_PATH"
    file_name="create-bcfks-$COMPONENT-secret.sh"
    
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
