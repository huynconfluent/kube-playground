#!/bin/sh

# ./create-file-userstore.sh -n "namespace" -e "crypt|md5|sha256|sha384|sha512|" -u "path_to_userstore.txt"
# credential file should be in following format username:clear-text-password

BASE_DIR=$(pwd)
GEN_DIR="$BASE_DIR/generated/userstore"
FILES_GEN_DIR="$GEN_DIR/files"
CMD_GEN_DIR="$GEN_DIR/cmd"
DEPLOY_CLEAN=false
REQUIRED_PKG="kubectl sha256sum sha384sum sha512sum openssl"
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

usage() {
    printf "Usage: $0 [-e] [string] [-u] [path] [-n] [string]\n"
    printf "\t-e [string]           (required) encryption type none|crypt|md5|sha256|sha384|sha512\n"
    printf "\t-u [path]             (required) credential file\n"
    printf "\t-n [string]           (required) namespace\n"
    printf "\t-c                    (optional) clean deployment\n"
    exit 1
}

while getopts "e:u:n:c" opt; do
    case $opt in
        e)
            # convert to uppercase
            ENCRYPTION=$(echo $OPTARG | tr '[:lower:]' '[:upper:]')
            ;;
        u)
            CRED_FILE=$OPTARG
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

if [ -z "$ENCRYPTION" ] || [ -z "$CRED_FILE" ] || [ -z "$NAMESPACE" ]; then
    printf "Error: $0 requires arguments\n"
    usage
fi

if [ "$ENCRYPTION" != "NONE" ] && [ "$ENCRYPTION" != "SHA256" ] && [ "$ENCRYPTION" != "SHA384" ] && [ "$ENCRYPTION" != "SHA512" ] && [ "$ENCRYPTION" != "CRYPT" ] && [ "$ENCRYPTION" != "MD5" ]; then
    printf "Encryption type unknown, must be none|crypt|md5|sha256|sha384|sha512\n"
    usage
fi

generate_userstore () {

    while IFS= read -r line; do

        # extract username + cleartext password
        username="$(echo $line | awk -F ':' '{ print $1 }')"
        password="$(echo $line | awk -F ':' '{ print $2 }')"

        # convert cleartext password
        case "$ENCRYPTION" in
            "SHA256")
                #printf "Converting password into SHA256\n"
                new_password=$(echo -n "$password" | sha256sum | awk '{printf $1}')
                ;;
            "SHA384")
                #printf "Converting password into SHA384\n"
                new_password=$(echo -n "$password" | sha384sum | awk '{printf $1}')
                ;;
            "SHA512")
                #printf "Converting password into SHA512\n"
                new_password=$(echo -n "$password" | sha512sum | awk '{printf $1}')
                ;;
            "CRYPT")
                #printf "Converting password into crypt\n"
                new_password=$(openssl passwd -salt salty $password)
                ;;
            "MD5")
                # md5 encrypt
                #printf "Converting password into md5\n"
                new_password=$(echo -n "$password" | openssl dgst -md5 | awk '{printf $2}')
                ;;
            "NONE")
                # do nothing
                ;;
            *)
                printf "Unknown ENCRYPTION type: %s\n" "$ENCRYPTION"
                exit 1
                ;;
        esac

        if [ "$ENCRYPTION" == "NONE" ]; then
            printf "%s:%s\n" "$username" "$password" >> "$FILES_GEN_DIR/$FILE_NAME.txt"
        else
            printf "%s:%s:%s\n" "$username" "$ENCRYPTION" "$new_password" >> "$FILES_GEN_DIR/$FILE_NAME.txt"
        fi
    done < $CRED_FILE
}

generate_bash_script () {

    secret_name="$FILE_NAME"
    file_path="$FILES_GEN_DIR/$FILE_NAME.txt"
    cmd="-n \$NAMESPACE create secret generic $secret_name --from-file=userstore.txt=$file_path"
    file_name="create-$secret_name-secret.sh"
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

source $BASE_DIR/scripts/system/header.sh -t "Generating File Based Userstore"

# Set FILE_NAME
if [ "$ENCRYPTION" == "NONE" ]; then
    FILE_NAME="cleartext-userstore"
else
    FILE_NAME="$ENCRYPTION-userstore"
fi

if [[ "$DEPLOY_CLEAN" == "true" ]]; then
    printf "Deleting generated file...\n"
    if [ -f "$FILES_GEN_DIR/$FILE_NAME.txt" ]; then
        rm -r "$FILES_GEN_DIR/$FILE_NAME.txt"
    else
        printf "File doesn't exist, skipping...\n"
    fi
fi

if [ ! -f "$FILES_GEN_DIR/$FILE_NAME.txt" ]; then
    printf "Creating Generated directory for userstore...\n"
    mkdir -p "$GEN_DIR"
    mkdir -p "$FILES_GEN_DIR"
    mkdir -p "$CMD_GEN_DIR"
    # create empty file
    echo "" > "$FILES_GEN_DIR/$FILE_NAME.txt"
fi

generate_userstore
generate_bash_script

source $BASE_DIR/scripts/system/header.sh -t "Completed Generating File Based Userstore"
