#!/bin/sh

# ./destroy-multipass.sh

REQUIRED_PKG="multipass"
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

# check if vm exist
if [ "$(multipass list | grep -c $MULTIPASS_VM_NAME)" -ge 1 ]; then
    printf "%s found in multipass list output\nDeleting VM....\n" "$MULTIPASS_VM_NAME"
    multipass delete $MULTIPASS_VM_NAME 
    multipass purge
    printf "Done!\n"
else
    printf "%s Not found, exiting...\n" "$MULTIPASS_VM_NAME"
fi
