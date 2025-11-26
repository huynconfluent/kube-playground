#!/bin/bash

# ./create-ca.sh "GTS Root X1" '{"C": "US","O": "Confluent Demo"}' "8760h" "rsa|ecdsa" "2048|4096"

REQUIRED_PKG="cfssl jq"
TEMPLATE_CA_JSON="$BASE_DIR/configs/cfssl/template_ca.json"
GEN_DIR="$BASE_DIR/generated/ssl"
CN=$1
DN=$2
EXPIRY=$3
KEY_ALGO=$4
KEY_SIZE=$5

# Check number of arguments
if [ "$#" -ne 5 ]; then
    printf "Command takes 5 arguments, exiting...\n\n"
    printf "./create-ca.sh \"COMMON_NAME\" '{\"C\":\"US\",\"O\": \"Confluent Demo\"}' \"4380h\" \"rsa|ecdsa\"\n\n"
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
mkdir -p $GEN_DIR/{templates,root_ca}

# generate root_ca template
printf "Generating root_ca template JSON...\n"
jq --arg cn "$CN" --argjson dn "$DN" --arg expiry "$EXPIRY" --arg key_algo "$KEY_ALGO" --argjson key_size "$KEY_SIZE" '.CN = $cn | .names[] = $dn | .CA.expiry = $expiry | .key.algo = $key_algo | .key.size = $key_size' "$TEMPLATE_CA_JSON" > "$GEN_DIR/templates/root_ca.json"

# create Root CA
printf "\nGenerating root_ca PEM files...\n"
cfssl gencert -initca "$GEN_DIR/templates/root_ca.json" | cfssljson -bare  "$GEN_DIR/root_ca/ca"

printf "Finished creating Root CA Certificate\n"
