#!/bin/bash

# ./create-keystore.sh -c "component name" -k "path_to_private_key" -a "path_to_fullchain" -p "keystore_password" -f -x

REQUIRED_PKG="curl openssl keytool"
OPTIND=1
GEN_DIR="$BASE_DIR/generated"
SSL_DIR="$GEN_DIR/ssl"
# FIPS 140-2 certified = 1.0.2.* releases until 2026 September
# FIPS 140-3 certified = 2.*
BC_VERSION="1.0.2.3"
BC_JAR="bc-fips-${BC_VERSION}.jar"
BC_JAR_URL="https://repo1.maven.org/maven2/org/bouncycastle/bc-fips/$BC_VERSION/$BC_JAR"
FIPS_ENABLED=false
CLEAN_BUILD=false

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

# make sure keytool is working
keytool -h > /dev/null 2>&1
if [ "$?" -ne 0 ]; then
    printf "keytool command not working as expected, exiting...\n"
    exit 1
fi

# flags
usage () {
    printf "Usage: $0 [-c] [string] [-k] [string] [-a] [string] [-p] [string] [-f] [-x]\n"
    printf "\t-c [component name]                   (required) component name\n"
    printf "\t-k [path to private key]              (required) path to private key PEM file\n"
    printf "\t-a [path to fullchain]                (required) path to fullchain PEM file\n"
    printf "\t-p [keystore password]                (required) keystore password\n"
    printf "\t-f                                    (optional) Create a Bouncy Castle Keystore\n"
    printf "\t-x                                    (optional) Clean build\n"
    printf "\t-h                                    help menu\n"
    exit 1
}

while getopts "c:k:a:p:fx" opt; do
    case $opt in
        c)
            # component name
            COMPONENT_NAME=$OPTARG
            ;;
        k)
            # private key
            CERT_KEY=$OPTARG
            ;;
        a)
            # path to fullchain
            CERT_PEM=$OPTARG
            ;;
        p)
            # keystore password
            KEYSTORE_PASSWORD=$OPTARG
            ;;
        f)
            # fips mode enabled
            FIPS_ENABLED=true
            ;;
        x)
            # clean build will delete existing files
            CLEAN_BUILD=true
            ;;
        *)
            usage
            ;;
    esac
done

# set the default if not set
if [ -z "$COMPONENT_NAME" ] || [ -z "$CERT_KEY" ] || [ -z "$CERT_PEM" ] || [ -z "$KEYSTORE_PASSWORD" ]; then
    printf "Parameters must be set!\n"
    usage
    exit 1
fi

KEYSTORE_PKS_FILE="$SSL_DIR/files/$COMPONENT_NAME.keystore.p12"
KEYSTORE_ALIAS="1"
KEYSTORE_JKS_FILE="$SSL_DIR/files/$COMPONENT_NAME.keystore.jks"
PASSWORD_FILE="$SSL_DIR/files/$COMPONENT_NAME.keystore.jksPassword.txt"
KEYSTORE_BCFKS_FILE="$SSL_DIR/files/$COMPONENT_NAME.keystore.bcfks"

download_bc_jar () {

    if [ ! -f "$GEN_DIR/jars" ]; then
       mkdir -p $GEN_DIR/jars 
    fi

    if [ ! -f "$GEN_DIR/jars/$BC_JAR" ]; then

        curl "$BC_JAR_URL" -o "$GEN_DIR/jars/$BC_JAR"
        
        if [ "$?" -ne 0 ]; then
            printf "There was an issue downloading the jar, exiting...\n"
            exit 1
        fi
    fi

}

create_bc_keystore () {

    # confirm that PKCS12 keystore exists
    if [ ! -f "$KEYSTORE_PKS_FILE" ]; then
        printf "PKCS12 keystore doesn't exist, required for conversion, exiting...\n"
        exit 1
    fi

    if [ -f "$KEYSTORE_BCFKS_FILE" ] && [ "$CLEAN_BUILD" == false ]; then
        printf "BCFKS keystore file exists, skipping...\n"
    else
        if [ "$CLEAN_BUILD" == true ]; then
            printf "Deleting existing BCFKS keystore file...\n"
            rm -f "$KEYSTORE_BCFKS_FILE"
        fi
        # generate BCFKS keystore
        keytool -importkeystore -srcstorepass $KEYSTORE_PASSWORD -srckeystore $KEYSTORE_PKS_FILE -srcstoretype pkcs12 -srcalias $KEYSTORE_ALIAS -destkeystore $KEYSTORE_BCFKS_FILE -deststoretype BCFKS -deststorepass $KEYSTORE_PASSWORD -destalias $KEYSTORE_ALIAS -providername BCFIPS -providerclass org.bouncycastle.jcajce.provider.BouncyCastleFipsProvider -providerpath $GEN_DIR/jars/$BC_JAR > /dev/null 2>&1
    fi

    # error checking
    if [ ! -f "$KEYSTORE_BCFKS_FILE" ]; then
        printf "BCFKS Keystore creation encountered an error...\n"
        exit 1
    fi


}

create_keystore () {

    if [ -f "$KEYSTORE_PKS_FILE" ] && [ "$CLEAN_BUILD" == false ]; then
        printf "PKCS12 keystore file exists, skipping...\n"
    else
        if [ "$CLEAN_BUILD" == true ]; then
            printf "Deleting existing PKCS12 keystore file...\n"
            rm -f "$KEYSTORE_PKS_FILE"
        fi
       
        # generate p12 with private key and public fullchain, must use -legacy option for OpenSSL 3.x
        printf "Create PKCS12 formatted keystore for %s...\n" "$COMPONENT_NAME"
        openssl pkcs12 -export -in $CERT_PEM -inkey $CERT_KEY -out $KEYSTORE_PKS_FILE -password "pass:${KEYSTORE_PASSWORD}" > /dev/null 2>&1
    fi

    # error checking
    if [ ! -f "$KEYSTORE_PKS_FILE" ]; then
        printf "PKCS12 Keystore creation encountered an error...\n"
        exit 1
    fi

    if [ -f "$KEYSTORE_JKS_FILE" ] && [ "$CLEAN_BUILD" == false ]; then
        printf "JKS keystore file exists, skipping...\n"
    else
        if [ "$CLEAN_BUILD" == true ]; then
            printf "Deleting existing JKS keystore file...\n"
            rm -f "$KEYSTORE_JKS_FILE"
        fi

        # convert to jks
        printf "Converting PKCS12 Formatted Keystore into JKS Formatted Keystore for %s...\n" "$COMPONENT_NAME"
        keytool -importkeystore -srcstorepass $KEYSTORE_PASSWORD -srckeystore $KEYSTORE_PKS_FILE -srcstoretype pkcs12 -srcalias $KEYSTORE_ALIAS -destkeystore $KEYSTORE_JKS_FILE -deststoretype jks -deststorepass $KEYSTORE_PASSWORD -destalias $KEYSTORE_ALIAS > /dev/null 2>&1
    fi

    # error checking
    if [ ! -f "$KEYSTORE_JKS_FILE" ]; then
        printf "JKS Keystore creation encountered an error...\n"
        exit 1
    fi


}

# create generated directories if missing
mkdir -p $SSL_DIR/files

# call create keystore
create_keystore

if [ "$FIPS_ENABLED" == true ]; then
    download_bc_jar
    
    # call create bcfks
    create_bc_keystore
fi

# generate jksPassword.txt
printf "Creating jksPassword.txt for %s...\n" "$COMPONENT_NAME"
printf "jksPassword=%s\n" "$KEYSTORE_PASSWORD" > "$PASSWORD_FILE"
