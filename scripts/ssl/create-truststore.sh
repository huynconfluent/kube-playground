#!/bin/bash

# ./create-truststore.sh "component" "path_to_cacerts" "keystore_password"

# TODO: Add option to create BCFKS https://docs.confluent.io/operator/current/co-security-compliance.html

REQUIRED_PKG="openssl keytool"
GEN_DIR="$BASE_DIR/generated/ssl"
COMPONENT_NAME=$1
CACERTS=$2
TRUSTSTORE_PASSWORD=$3
TRUSTSTORE_FILE="$GEN_DIR/files/$COMPONENT_NAME.truststore.p12"
TRUSTSTORE_JKS_FILE="$GEN_DIR/files/$COMPONENT_NAME.truststore.jks"
CA_ALIAS="caroot"
PASSWORD_FILE="$GEN_DIR/files/$COMPONENT_NAME.truststore.jksPassword.txt"

# Check number of arguments
if [ "$#" -ne 3 ]; then
    printf "Command takes 3 arguments, exiting...\n\n"
    printf "./create-truststore.sh \"component name\" \"path_to_cacerts\" \"keystore_password\"\n"
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
mkdir -p $GEN_DIR/files

# generate p12 truststore
rm -f "$TRUSTSTORE_FILE"
rm -f "$TRUSTSTORE_JKS_FILE"
printf "Create PKCS12 formatted truststore for %s...\n" "$COMPONENT_NAME"
openssl pkcs12 -export -nokeys -in $CACERTS -out $TRUSTSTORE_FILE -caname $CA_ALIAS -password "pass:${TRUSTSTORE_PASSWORD}" -jdktrust anyExtendedKeyUsage > /dev/null 2>&1

# error checking
if [ ! -f "$TRUSTSTORE_FILE" ]; then
    printf "PKCS12 Truststore creation encountered an error...\n"
    exit 1
fi

# convert to jks
printf "Converting PKCS12 Formatted Truststore into JKS Formatted Truststore for %s...\n" "$COMPONENT_NAME"
# loop through pkcs12 truststore
keytool -list -keystore $TRUSTSTORE_FILE -storepass $TRUSTSTORE_PASSWORD | grep 'trustedCertEntry' | sed -E "s/^([0-9a-zA-Z]*),.*/\1/g" | while IFS= read -r line; do
    printf "Importing Certificate %s\n" "$line"
    keytool -importkeystore -srcstorepass $TRUSTSTORE_PASSWORD -srckeystore $TRUSTSTORE_FILE -srcstoretype pkcs12 -srcalias $line -destkeystore $TRUSTSTORE_JKS_FILE -deststoretype jks -deststorepass $TRUSTSTORE_PASSWORD -destalias $line > /dev/null 2>&1
done

# error checking
if [ ! -f "$TRUSTSTORE_JKS_FILE" ]; then
    printf "JKS Truststore creation encountered an error...\n"
    exit 1
fi

# generate jksPassword.txt
printf "Creating jksPassword.txt for %s...\n" "$COMPONENT_NAME"
printf "jksPassword=%s\n" "$TRUSTSTORE_PASSWORD" > "$PASSWORD_FILE"
