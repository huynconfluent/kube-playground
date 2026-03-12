#!/bin/sh

BASE_DIR=$(pwd)
REQUIRED_PKG="k3d kubectl jq"
ETC_HOST="/etc/hosts"
TMP_ETC_HOST="/etc/hosts.tmp"
set -o allexport; source $BASE_DIR/.env; set +o allexport

# for macOS specifically
if [ "$(uname)" != "Darwin" ]; then
    printf "This script is only meant for MacOS, exiting...\n"
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

source $BASE_DIR/scripts/system/header.sh -t "Configurating /etc/hosts"

if [ $(k3d cluster list | grep -ic $K3D_CLUSTER_NAME) -ne 1 ]; then
    printf "Kubernetes Cluster is probably not running, exiting...\n"
    exit 1
fi

checkHostFile () {

    if [ "$(grep -Ec "^# [a-zA-Z0-9-]+\.${KUBE_BASEDOMAIN} Added by kube-playground$" $ETC_HOST)" -gt 0 ]; then
        printf "There are custom records found!\n"
        printf "Clearing custom records with based domain: %s...\n" "$KUBE_BASEDOMAIN"
        # create a tmp file with the proposed change
        sed -E "/.*[a-zA-Z0-9-]+\.${KUBE_BASEDOMAIN}.*/d" $ETC_HOST | sudo tee $TMP_ETC_HOST > /dev/null
        # replace /etc/hosts with the tmp file
        if grep -q '[^[:space:]]' "$TMP_ETC_HOST"; then
            # file is safe to replace
            # backup file before deletion
            printf "Backing up %s ...\n" "$ETC_HOST"
            sudo cp $ETC_HOST $ETC_HOST.bk.$(date +"%Y-%m-%d-%H-%M-%S")
            sudo cp "$TMP_ETC_HOST" "$ETC_HOST"
            printf "%s is now cleared of custom records!\n" "$ETC_HOST"
        else
            # file is empty and should not be replaced
            printf "%s is empty, something must have gone wrong, exiting...\n" "$TMP_ETC_HOST"
            exit 1
        fi
    else
        printf "There are no custom records\n"
    fi
}

addHostRecord () {

    l_namespace=$1

    # check that there's any external IPs to begin with?
    kubectl -n $l_namespace get svc -o json | jq -r '.items[] | select(.status.loadBalancer.ingress != null) | "\(.metadata.name) \(.status.loadBalancer.ingress[0].ip)"' | while read -r name ip; do
        # remove postfix
        l_name=$(echo "$name" | sed -E "s/^([a-zA-Z]*)([0-9-]*)(-bootstrap-lb|-lb)+$/\1\2.$KUBE_BASEDOMAIN/")
        
        printf "Adding record for %s\n" "$l_name"
        echo "# $l_name Added by kube-playground" | sudo tee -a "$ETC_HOST" > /dev/null
        echo "$ip $l_name" | sudo tee -a "$ETC_HOST" > /dev/null
    done
}

# check for existing custom records and delete them
checkHostFile

if [ ! -z "$IDENTITY_NAMESPACE" ]; then
    addHostRecord "$IDENTITY_NAMESPACE"
else
    printf "No Identity Namespace set, skipping...\n"
fi
if [ ! -z "$CFK_NAMESPACE" ]; then
    addHostRecord "$CFK_NAMESPACE"
else
    printf "No CFK Namespace set, skipping...\n"
fi
if [ ! -z "$HASHICORP_VAULT_NAMESPACE" ]; then
    addHostRecord "$HASHICORP_VAULT_NAMESPACE"
else
    printf "No Hashicorp Vault Namespace set, skipping...\n"
fi
if [ ! -z "$CERT_MANAGER_NAMESPACE" ]; then
    addHostRecord "$CERT_MANAGER_NAMESPACE"
else
    printf "No Cert Manager Namespace set, skipping...\n"
fi
if [ ! -z "$FLINK_OPERATOR_NAMESPACE" ]; then
    addHostRecord "$FLINK_OPERATOR_NAMESPACE"
else
    printf "No Hashicorp Vault Namespace set, skipping...\n"
fi

source $BASE_DIR/scripts/system/header.sh -t "Completed!"
