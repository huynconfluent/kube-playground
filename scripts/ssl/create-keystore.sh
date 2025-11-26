#!/bin/bash

# ./create-keystore.sh "component name" "path_to_private_key" "path_to_fullchain" "keystore_password"

# TODO: Add option to create BCFKS https://docs.confluent.io/operator/current/co-security-compliance.html

REQUIRED_PKG="openssl keytool"
GEN_DIR="$BASE_DIR/generated/ssl"
COMPONENT_NAME=$1
CERT_KEY=$2
CERT_PEM=$3
KEYSTORE_PASSWORD=$4
KEYSTORE_FILE="$GEN_DIR/files/$COMPONENT_NAME.keystore.p12"
KEYSTORE_ALIAS="1"
KEYSTORE_JKS_FILE="$GEN_DIR/files/$COMPONENT_NAME.keystore.jks"

# Check number of arguments
if [ "$#" -ne 4 ]; then
    printf "Command takes 4 arguments, exiting...\n\n"
    printf "./create-keystore.sh \"component name\" \"path_to_private_key\" \"path_to_fullchain\" \"keystore_password\"\n"
    exit 1
fi

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
mkdir -p $GEN_DIR/{files}

# generate p12 with private key and public fullchain, must use -legacy option for OpenSSL 3.x
rm -f "$KEYSTORE_FILE"
rm -f "$KEYSTORE_JKS_FILE"
printf "Create PKCS12 formatted keystore for %s...\n" "$COMPONENT_NAME"
openssl pkcs12 -export -in $CERT_PEM -inkey $CERT_KEY -out $KEYSTORE_FILE -password "pass:${KEYSTORE_PASSWORD}" > /dev/null 2>&1

# error checking
if [ ! -f "$KEYSTORE_FILE" ]; then
    printf "PKCS12 Keystore creation encountered an error...\n"
    exit 1
fi

# convert to jks
printf "Converting PKCS12 Formatted Keystore into JKS Formatted Keystore for %s...\n" "$COMPONENT_NAME"
keytool -importkeystore -srcstorepass $KEYSTORE_PASSWORD -srckeystore $KEYSTORE_FILE -srcstoretype pkcs12 -srcalias $KEYSTORE_ALIAS -destkeystore $KEYSTORE_JKS_FILE -deststoretype jks -deststorepass $KEYSTORE_PASSWORD -destalias $KEYSTORE_ALIAS > /dev/null 2>&1

# error checking
if [ ! -f "$KEYSTORE_JKS_FILE" ]; then
    printf "JKS Keystore creation encountered an error...\n"
    exit 1
fi
