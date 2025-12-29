#!/bin/sh

# ./deploy-hashicorp-vault.sh

BASE_DIR=$(pwd)
REQUIRED_PKG="kubectl helm"
HASHICORP_VAULT_REPO_NAME="hashicorp"
HASHICORP_VAULT_HELM_NAME="vault"
HASHICORP_VAULT_HELM_REPO="https://helm.releases.hashicorp.com"
set -o allexport; source .env; set +o allexport

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

#printf "\n====Deploying Hashicorp Vault====\n"
source $BASE_DIR/scripts/system/header.sh -t "Deploying Hashicorp Vault"

# adding repo
helm repo add $HASHICORP_VAULT_REPO_NAME $HASHICORP_VAULT_HELM_REPO

# check that hashicorp namespace hasn't been created yet
if [ $(kubectl get ns | grep -ic $HASHICORP_VAULT_NAMESPACE) -eq 0 ]; then
    printf "\nCreating Namespace %s for Hashicorp Vault Deployment.......\n" "${HASHICORP_VAULT_NAMESPACE}"

    kubectl create namespace $HASHICORP_VAULT_NAMESPACE
fi

# check that hashicorp vault hasn't been deployed yet
if [ $(kubectl -n $HASHICORP_VAULT_NAMESPACE get sts 2>&1 | grep -ic "${HASHICORP_VAULT_HELM_NAME}") -eq 0 ]; then
   
    printf "\nDeploying %s in %s Namespace.......\n" "$HASHICROP_VAULT_HELM_NAME" "$HASHICORP_VAULT_NAMESPACE"

    helm upgrade --install $HASHICORP_VAULT_HELM_NAME --set='server.dev.enabled=true' $HASHICORP_VAULT_REPO_NAME/vault -n $HASHICORP_VAULT_NAMESPACE

    if [ $(echo $?) -ne 0 ]; then
        printf "\nEncountered an error, exiting....\n"
        exit 1
    fi

    # wait for vault to be ready
    timeout=60
    sleep_in_seconds=5
    while [ "$(kubectl -n ${HASHICORP_VAULT_NAMESPACE} get pod $HASHICORP_VAULT_HELM_NAME-0 | grep -c '1/1')" -lt 1 ]; do
        if [ $timeout -le 0 ]; then
            printf "\nTimed out waiting on Vault, %s seconds\n" "$timeout"
            exit 1
        fi
        printf "\nWaiting for Vault to be ready..."
        sleep $sleep_in_seconds
        timeout=$((timeout-sleep_in_seconds))
    done

    printf "\n"

else
    printf "\n%s is already deployed in %s namespace, skipping deployment....\n" "$HASHICORP_VAULT_HELM_NAME" "$HASHICORP_VAULT_NAMESPACE"
fi

printf "\nConfiguring Vault for Kubernetes...\n"
# copy our executable into vault pod
kubectl -n $HASHICORP_VAULT_NAMESPACE cp $BASE_DIR/scripts/helper/vault-cmd.sh vault-0:/tmp

# execute vault commands based on https://github.com/confluentinc/confluent-kubernetes-examples/tree/master/security/configure-with-vault
kubectl -n $HASHICORP_VAULT_NAMESPACE exec -ti vault-0 -- sh /tmp/vault-cmd.sh

printf "\nVault Configuration completed!\n"
