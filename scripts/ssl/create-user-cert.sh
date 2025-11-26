#!/bin/bash

# ./create-user-cert.sh "COMMON_NAME" '{"C": "US", "O": "Confluent Demo", "OU": "GTS Support Group"}' '["san_1","san_2","san_3"]' "2190h" "rsa|ecdsa" "2048|4096" "GEN_DIR/root_ca/ca.pem" "GEN_DIR/root_ca/ca-key.pem" "GEN_DIR/files/cacerts.pem" "server|client|server_and_client"

REQUIRED_PKG="cfssl jq"
TEMPLATE_PROFILE="$BASE_DIR/configs/cfssl/template_profile.json"
TEMPLATE_CERT="$BASE_DIR/configs/cfssl/template_cert.json"
GEN_DIR="$BASE_DIR/generated/ssl"
CN=$1
DN=$2
SAN=$3
EXPIRY=$4
KEY_ALGO=$5
KEY_SIZE=$6
CA_CERT=$7
CA_KEY=$8
CA_CHAIN=$9
CERT_PROFILE=${10}
# Cert Profile
if [ "$CERT_PROFILE" != "server" ] && [ "$CERT_PROFILE" != "client" ] && [ "$CERT_PROFILE" != "server_and_client" ]; then
    printf "Must use server|client|server_and_client option, exiting...\n"
    exit 1
fi
DESIRED_LENGTH=20
SHORT_NAME=$(echo $CN | sed 's/ /_/g' | cut -c -$DESIRED_LENGTH | sed 's/[_]*//')

# Check number of arguments
if [ "$#" -ne 10 ]; then
    printf "Command takes 10 arguments, exiting...\n\n"
    printf "./create-user-cert.sh \"COMMON_NAME\" '{\"C\": \"US\", \"O\": \"Confluent Demo\", \"OU\": \"GTS Support Group\"}' '[\"san_1\",\"san_2\",\"san_3\"]' \"2190h\" \"rsa|ecdsa\" \"2048|4096\" \"PATH_TO_CA_PEM\" \"PATH_TO_CA_KEY\" \"PATH_TO_CA_CHAIN\" \"server|client|server_and_client\"\n\n"
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

# Checking that ca cert and key exist
if [ ! -f "$CA_CERT" ] && [ ! -f "$CA_KEY" ] [ ! -f "$CA_CHAIN" ]; then
    printf "\nroot_ca Cert, Key and/or CA Cert Chain not found, exiting...\n"
    exit 1
fi

# create generated directories if missing
mkdir -p $GEN_DIR/{templates,components,files}

# copy template_profile.json to generated directory
jq --arg expiry "$EXPIRY" '.signing.profiles.server.expiry = $expiry | .signing.profiles.client.expiry = $expiry | .signing.profiles.server_and_client.expiry = $expiry' "$TEMPLATE_PROFILE" > "$GEN_DIR/templates/profile.json"
# create server json
printf "Creating %s Server Cert JSON...\n" "$CN"
jq --arg cn "$CN" --argjson hosts "$SAN" --argjson names "$DN" --arg key_algo "$KEY_ALGO" --argjson key_size "$KEY_SIZE" '.CN = $cn | .hosts += $hosts | .names[] += $names | .key.algo += $key_algo | .key.size += $key_size' "$TEMPLATE_CERT" > "$GEN_DIR/templates/component_$SHORT_NAME.json"
# generate server cert
printf "Creating %s Server Cert PEM files...\n" "$CN"
cfssl gencert -ca "$CA_CERT" -ca-key "$CA_KEY" -config "$GEN_DIR/templates/profile.json" -profile $CERT_PROFILE "$GEN_DIR/templates/component_$SHORT_NAME.json" | cfssljson -bare "$GEN_DIR/components/$SHORT_NAME"

# create fullchain
printf "Creating %s Full Chain PEM file...\n" "$CN"
cat "$GEN_DIR/components/$SHORT_NAME.pem" "$CA_CHAIN" > "$GEN_DIR/components/$SHORT_NAME-fullchain.pem"

# create keystore file
printf "Creating Keystore and Truststore files...\n"
source $BASE_DIR/scripts/ssl/create-keystore-new.sh "$SHORT_NAME" "$GEN_DIR/components/$SHORT_NAME-key.pem" "$GEN_DIR/components/$SHORT_NAME-fullchain.pem" "topsecret"
