#!/bin/bash

# ./create-mds-keypair.sh

REQUIRED_PKG="openssl"
GEN_DIR="$BASE_DIR/generated/ssl"
MDS_KEYPAIR_PATH="$GEN_DIR/files/keypair"
MDS_PRIVATE_KEY="$MDS_KEYPAIR_PATH/mds-keypair-private.pem"
MDS_PUBLIC_KEY="$MDS_KEYPAIR_PATH/mds-keypair-public.pem"
KEY_SIZE=2048

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

# create generated directories if missing
mkdir -p $MDS_KEYPAIR_PATH

# Generate Private Key
printf "Generating MDS Keypair...\n"
openssl genrsa -out $MDS_PRIVATE_KEY $KEY_SIZE
# Extract Public Key
openssl rsa -in $MDS_PRIVATE_KEY -outform PEM -pubout -out $MDS_PUBLIC_KEY
