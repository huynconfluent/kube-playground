#!/bin/bash

# ./create-intermediate-ca.sh "1" "GTS Intermediate X" '{"C": "US", "O": "Confluent Demo"}' "4380h" "rsa|ecdsa" "2048|4096" "GEN_DIR/root_ca/ca.pem" "GEN_DIR/root_ca/ca-key.pem"

REQUIRED_PKG="cfssl jq"
TEMPLATE_CA_JSON="$BASE_DIR/configs/cfssl/template_ca.json"
TEMPLATE_PROFILE="$BASE_DIR/configs/cfssl/template_profile.json"
GEN_DIR="$BASE_DIR/generated/ssl"
CHAIN_COUNT=$1
CN=$2
DN=$3
EXPIRY=$4
KEY_ALGO=$5
KEY_SIZE=$6
ROOT_CA=$7
ROOT_KEY=$8

# Check number of arguments
if [ "$#" -ne 8 ]; then
    printf "Command takes 8 arguments, exiting...\n\n"
    printf "./create-intermediate-ca.sh \"CERT_CHAIN_COUNT\" \"COMMON_NAME_BASE\" '{\"C\":\"US\",\"O\": \"Confluent Demo\"}' \"4380h\" \"rsa|ecdsa\" \"PATH_TO_ROOT_CA_PEM\" \"PATH_TO_ROOT_CA_KEY\"\n\n"
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

# Checking that root_ca cert and key exist
if [ ! -f "$ROOT_CA" ] && [ ! -f "$ROOT_KEY" ]; then
    printf "\nroot_ca Cert and/or Key not found, exiting...\n"
    exit 1
fi

# create generated directories if missing
mkdir -p $GEN_DIR/{templates,intermediate_ca,files}

for (( i=1; i<=$CHAIN_COUNT; ++i)); do
    # set PATHLEN
    if [ "$i" -eq "$CHAIN_COUNT" ]; then
        PATHLEN=0
        # copy template_profile.json to generated direcotry
        jq --arg expiry "$EXPIRY" '.signing.profiles.intermediate.expiry = $expiry' "$TEMPLATE_PROFILE" > "$GEN_DIR/templates/profile.json"
    else
        PATHLEN=1
        # copy template_profile.json to generated direcotry
        jq --arg expiry "$EXPIRY" --argjson pathlen "$PATHLEN" '.signing.profiles.intermediate.expiry = $expiry | .signing.profiles.intermediate.ca_constraint.max_path_len = $pathlen | .signing.profiles.intermediate.ca_constraint.max_path_len_zero = false' "$TEMPLATE_PROFILE" > "$GEN_DIR/templates/profile.json"
    fi

    # create intermediate ca json
    printf "Creating Intermediate CA%s JSON...\n" "$i"
    jq --arg cn "$CN$i" --argjson dn "$DN" --arg expiry "$EXPIRY" --arg key_algo "$KEY_ALGO" --argjson key_size "$KEY_SIZE" --argjson pathlen "$PATHLEN" '.CN = $cn | .names[] = $dn | .CA.expiry = $expiry | .key.algo = $key_algo | .key.size = $key_size | .CA.pathlen = $pathlen' "$TEMPLATE_CA_JSON" > "$GEN_DIR/templates/intermediate_ca_$i.json"
    # generate intermediate ca
    printf "Creating Intermediate CA%s PEM files...\n" "$i"
    cfssl genkey -initca "$GEN_DIR/templates/intermediate_ca_$i.json" | cfssljson -bare "$GEN_DIR/intermediate_ca/intermediate_$i"
    printf "Signing Intermediate CA%s...\n" "$i"
    # sign with previous ca
    if [ "$i" -eq 1 ]; then
        # sign with root_ca
        cfssl sign -ca "$ROOT_CA" -ca-key "$ROOT_KEY" -profile intermediate --config "$GEN_DIR/templates/profile.json" "$GEN_DIR/intermediate_ca/intermediate_$i.csr" | cfssljson -bare "$GEN_DIR/intermediate_ca/intermediate_$i"
    else
        # sign with previous intermediate_ca
        previous=$((i - 1))
        cfssl sign -ca "$GEN_DIR/intermediate_ca/intermediate_$previous.pem" -ca-key "$GEN_DIR/intermediate_ca/intermediate_$previous-key.pem" -profile intermediate --config "$GEN_DIR/templates/profile.json" "$GEN_DIR/intermediate_ca/intermediate_$i.csr" | cfssljson -bare "$GEN_DIR/intermediate_ca/intermediate_$i"
    fi
done

printf "Creating cacerts.pem...\n"
# clear fullchain
printf "" > $GEN_DIR/files/cacerts.pem

# create intermediate cert chain
for ((j=$CHAIN_COUNT; j>=1; --j)); do
    cat $GEN_DIR/intermediate_ca/intermediate_$j.pem >> $GEN_DIR/files/cacerts.pem
done
cat $ROOT_CA >> $GEN_DIR/files/cacerts.pem

printf "Finished Creating Intermediate CA Certificates!\n"
