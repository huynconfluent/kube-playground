#!/bin/bash

# ./create-cmf-key.sh -n "namespace"

BASE_DIR=$(pwd)
OPTIND=1
REQUIRED_PKG="openssl"
GEN_DIR="$BASE_DIR/generated/ssl/files/cmf"
CMD_DIR="$BASE_DIR/generated/ssl/cmd/cmf"
CMF_KEY_NAME="cmf.key"
CMF_SECRET_NAME="cmf-encryption-key"
FILE_NAME="create-cmf-encryption-secret.sh"

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
    printf "Usage: $0 [-n] [string]\n"
    printf "\t-n namespace                 (required) namespace\n"
    exit 1
}

while getopts "n:" opt; do
    case $opt in
        n)
            NAMESPACE=$OPTARG
            ;;
        *)
            usage
            ;;
    esac
done

# ensure input has value
if [ -z "$NAMESPACE" ]; then
    printf "Error: $0 requires argument\n"
    usage
fi

# create generated directories if missing
if [ ! -d "$GEN_DIR" ]; then
    printf "\nCreating Generated Directory path...\n"
    mkdir -p $GEN_DIR
fi

# generate key
printf "\nGenerating CMF encryption key...\n"
openssl rand -out $GEN_DIR/$CMF_KEY_NAME 32

# creating bash script
CMD="-n \$NAMESPACE create secret generic $CMF_SECRET_NAME --from-file=encryption-key=$GEN_DIR/$CMF_KEY_NAME"

# uncomment to debug
#printf "\nKubectl Command: eval kubectl|oc %s\n" "$cmd"

# Create cmd direcotry for component
if [ ! -d "$CMD_DIR" ]; then
    printf "\nMaking Command directory in %s...\n" "$CMD_DIR"
    mkdir -p "$CMD_DIR"
fi

printf "#!/bin/sh\n\n" > $CMD_DIR/$FILE_NAME
printf "# ./$file_name [kubectl|oc] [namespace]\n\n" >> $CMD_DIR/$FILE_NAME
printf "KCMD=\${1:-kubectl}\n" >> $CMD_DIR/$FILE_NAME
printf "NAMESPACE=\${2:-%s}\n" "$NAMESPACE" >> $CMD_DIR/$FILE_NAME
printf "eval \"\$KCMD %s\"\n" "$CMD" >> $CMD_DIR/$FILE_NAME
chmod +x "$CMD_DIR/$FILE_NAME"

printf "Created bash script at %s\n" "$CMD_DIR/$FILE_NAME"
printf "Finished creating CMF Encryption Key\n"
