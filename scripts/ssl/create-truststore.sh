#!/bin/bash

# ./create-truststore.sh -c "component" -a "path_to_cacerts" -p "keystore_password" -f -x

REQUIRED_PKG="curl openssl keytool"
OPTIND=1
GEN_DIR="$BASE_DIR/generated"
SSL_DIR="$GEN_DIR/ssl"
CA_ALIAS="caroot"
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
    printf "Usage: $0 [-c] [string] [-a] [string] [-p] [string] [-f] [-x]\n"
    printf "\t-c [component name]                   (required) component name\n"
    printf "\t-a [path to cacerts]                  (required) path to cacerts\n"
    printf "\t-p [truststore password]              (required) truststore password\n"
    printf "\t-f                                    (optional) Create a Bouncy Castle Keystore\n"
    printf "\t-x                                    (optional) Clean build\n"
    printf "\t-h                                    help menu\n"
    exit 1
}

while getopts "c:a:p:fx" opt; do
    case $opt in
        c)
            # component name
            COMPONENT_NAME=$OPTARG
            ;;
        a)
            # path to cacerts
            CACERTS=$OPTARG
            ;;
        p)
            # keystore password
            TRUSTSTORE_PASSWORD=$OPTARG
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
if [ -z "$COMPONENT_NAME" ] || [ -z "$CACERTS" ] || [ -z "$TRUSTSTORE_PASSWORD" ]; then
    printf "Parameters must be set!\n"
    usage
    exit 1
fi

# Set file path
TRUSTSTORE_JKS_FILE="$SSL_DIR/files/$COMPONENT_NAME.truststore.jks"
TRUSTSTORE_PKS_FILE="$SSL_DIR/files/$COMPONENT_NAME.truststore.p12"
TRUSTSTORE_BCFKS_FILE="$SSL_DIR/files/$COMPONENT_NAME.truststore.bcfks"
PASSWORD_FILE="$SSL_DIR/files/$COMPONENT_NAME.truststore.jksPassword.txt"

download_bc_jar () {

    if [ ! -f "$GEN_DIR/jars" ]; then
       mkdir -p $GEN_DIR/jars 
    fi

    if [ ! -f "$GEN_DIR/jars/$BC_JAR" ]; then
        curl "$BC_JAR_URL" -o "$GEN_DIR/jars/$BC_JAR"
    fi

    if [ "$?" -ne 0]; then
        printf "There was an issue downloading the jar, exiting...\n"
        exit 1
    fi
}

create_bc_truststore () {

    cmd="keytool -noprompt -keystore $TRUSTSTORE_BCFKS_FILE -storetype BCFKS -alias $CA_ALIAS -import -file $CACERTS -storepass $TRUSTSTORE_PASSWORD -keypass $TRUSTSTORE_PASSWORD -providerclass org.bouncycastle.jcajce.provider.BouncyCastleFipsProvider -providerpath $GEN_DIR/jars/$BC_JAR"

    if [ -f "$TRUSTSTORE_BCFKS_FILE" ] && [ "$CLEAN_BUILD" == false ]; then
        printf "BCFKS truststore file exists, skipping...\n"
    else
        if [ "$CLEAN_BUILD" == true ]; then
            printf "Deleting existing BCFKS truststore file...\n"
            rm -f "$TRUSTSTORE_BCFKS_FILE"
        fi
        # create truststore
        printf "Creating BCFKS truststore...\n"
        printf "\n%s\n" "$cmd"
        eval $cmd
    fi
}

create_truststore () {

    if [ -f "$TRUSTSTORE_PKS_FILE" ] && [ "$CLEAN_BUILD" == false ]; then
        printf "PKCS12 truststore file exists, skipping...\n"
    else
        if [ "$CLEAN_BUILD" == true ]; then
            printf "Deleting existing PKCS12 truststore file...\n"
            rm -f "$TRUSTSTORE_PKS_FILE"
        fi

        # generate pkcs12 truststore
        printf "Create PKCS12 formatted truststore for %s...\n" "$COMPONENT_NAME"
        openssl pkcs12 -export -nokeys -in $CACERTS -out $TRUSTSTORE_PKS_FILE -caname $CA_ALIAS -password "pass:${TRUSTSTORE_PASSWORD}" -jdktrust anyExtendedKeyUsage > /dev/null 2>&1

    fi

    # error checking
    if [ ! -f "$TRUSTSTORE_PKS_FILE" ]; then
        printf "PKCS12 Truststore creation encountered an error...\n"
        exit 1
    fi

    if [ -f "$TRUSTSTORE_JKS_FILE" ] && [ "$CLEAN_BUILD" == false ]; then
        printf "JKS truststore file exists, skipping...\n"
    else
        if [ "$CLEAN_BUILD" == true ];then
            printf "Deleting existing JKS truststore file...\n"
            rm -f "$TRUSTSTORE_JKS_FILE"
        fi

        # convert to jks
        printf "Converting PKCS12 Formatted Truststore into JKS Formatted Truststore for %s...\n" "$COMPONENT_NAME"
        # loop through pkcs12 truststore
        keytool -list -keystore $TRUSTSTORE_PKS_FILE -storepass $TRUSTSTORE_PASSWORD | grep 'trustedCertEntry' | sed -E "s/^([0-9a-zA-Z]*),.*/\1/g" | while IFS= read -r line; do
        printf "Importing Certificate %s\n" "$line"
        keytool -importkeystore -srcstorepass $TRUSTSTORE_PASSWORD -srckeystore $TRUSTSTORE_PKS_FILE -srcstoretype pkcs12 -srcalias $line -destkeystore $TRUSTSTORE_JKS_FILE -deststoretype jks -deststorepass $TRUSTSTORE_PASSWORD -destalias $line > /dev/null 2>&1
        done

    fi

    # error checking
    if [ ! -f "$TRUSTSTORE_JKS_FILE" ]; then
        printf "JKS Truststore creation encountered an error...\n"
        exit 1
    fi

}

# create generated directories if missing
mkdir -p $SSL_DIR/files

if [ "$FIPS_ENABLED" == true ]; then
    download_bc_jar
    
    # call create bcfks
    create_bc_truststore
fi

# call create truststore
create_truststore

# generate jksPassword.txt
printf "Creating jksPassword.txt for %s...\n" "$COMPONENT_NAME"
printf "jksPassword=%s\n" "$TRUSTSTORE_PASSWORD" > "$PASSWORD_FILE"
