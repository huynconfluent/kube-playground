#!/bin/sh

# ./create-mds-binduser.sh -u "bind user" -p "bind password" -n "namespace"

BASE_DIR=$(pwd)
GEN_DIR="$BASE_DIR/generated/creds/mds"
FILE_NAME="ldap.txt"
DEPLOY_CLEAN=false
OPTIND=1
set -o allexport; source .env; set +o allexport

# flags
usage () {
    printf "Usage: $0 [-u] [string] [-p] [string] [-n] [string] -[c]\n"
    printf "\t-u username                       (required) ldap bind user\n"
    printf "\t-p password                       (required) ldap bind user password\n"
    printf "\t-n namespace                      (required) kubernetes namesapce to use in script, e.g. confluent\n"
    printf "\t-c                                (optional) clean deployment\n"
    exit 1
}

while getopts "u:p:n:c" opt; do
    case $opt in
        u)
            BIND_USERNAME=$OPTARG
            ;;
        p)
            BIND_PASSWORD=$OPTARG
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
if [ -z "$BIND_USERNAME" ] || [ -z "$BIND_PASSWORD" ] || [ -z "$NAMESPACE" ]; then
    printf "Error: $0 requires arguments\n"
    usage
fi

generate_cred_file () {

    if [ -f "$GEN_DIR/files/$FILE_NAME" ]; then
        printf "ldap.txt exists, skipping creation!\n"
    fi

    printf "username=%s\npassword=%s\n" "$BIND_USERNAME" "$BIND_PASSWORD" > $GEN_DIR/files/$FILE_NAME
}

generate_bash_script () {

    cmd="-n \$NAMESPACE create secret generic mds-binduser --from-file=ldap.txt=$GEN_DIR/files/$FILE_NAME"
    file_name="create-mds-binduser-secret.sh"
    
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

source $BASE_DIR/scripts/system/header.sh -t "Auto Generating MDS Bind User Assets"

generate_cred_file

generate_bash_script

source $BASE_DIR/scripts/system/header.sh -t "Completed Generating MDS Bind User Assets"
