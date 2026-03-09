#!/bin/sh

# ./create-bearer-auth.sh -u "user_json" -n "namespace" -c

BASE_DIR=$(pwd)
GEN_DIR="$BASE_DIR/generated/creds/bearer"
CMD_GEN_DIR="$GEN_DIR/cmd"
DEPLOY_CLEAN=false
REQUIRED_PKG="jq"
OPTIND=1
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
    printf "Usage: $0 [-u] [string] [-n] [string] [-c]\n"
    printf "\t-u [user_json]                        (required) user json containing credentials\n"
    printf "\t-n [namespace]                        (required) kubernetes namesapce to use in script, e.g. confluent\n"
    printf "\t-c                                    (optional) clean deployment\n"
    exit 1
}

while getopts "u:n:c" opt; do
    case $opt in
        u)
            USER_JSON=$OPTARG
            # validation checking
            if [[ "$(jq -e . $USER_JSON >/dev/null 2>&1)" -ne 0 ]]; then
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

generate_bash_script () {

    l_username=$1
    l_namespace=$2

    cmd="-n \$NAMESPACE create secret generic bearer-$l_username --from-file=bearer.txt=$GEN_DIR/files/$l_username-bearer.txt"
    file_name="create-bearer-$l_username-secret.sh"

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

generate_cred_file () {

    l_username=$1
    l_password=$2
    
    # create bearer.txt
    printf "Creating bearer.txt for %s\n" "$l_username"
    printf "username=%s\npassword=%s\n" "$l_username" "$l_password" > "$GEN_DIR/files/$l_username-bearer.txt"

}


source $BASE_DIR/scripts/system/header.sh -t "Auto Generating Bearer Credential Assets"

# remove generated files?
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

# loop
USER_DATA=( $(cat $USER_JSON | jq -r 'keys_unsorted[]' ) )

for user in "${USER_DATA[@]}"; do
    user_password=$(cat $USER_JSON | jq -r .[\"${user}\"])
    generate_cred_file "$user" "$user_password"
    generate_bash_script "$user" "$NAMESPACE"
done
