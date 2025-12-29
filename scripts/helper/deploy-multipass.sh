#!/bin/sh

# ./deploy-multipass.sh

REQUIRED_PKG="multipass"
GEN_DIR="$BASE_DIR/generated/multipass"
set -o allexport; source .env; set +o allexport

CPU_CORES=$MULTIPASS_VM_CPU_CORES
MEMORY=$MULTIPASS_VM_MEMORY
DISK=$MULTIPASS_VM_DISK

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

create_export () {

    # copy kubeconfig to local machine
    if [ ! -d "$GEN_DIR" ]; then
        printf "%s doesn't exist, creating...\n" "$GEN_DIR"
        mkdir -p "$GEN_DIR"
    fi
    printf "Copying kubeconfig to local machine...\n"
    multipass transfer "$MULTIPASS_VM_NAME:/home/ubuntu/.kube/config" "$GEN_DIR/kubeconfig"
    printf "Copied kubeconfig to local machine in %s\n" "$GEN_DIR/kubeconfig"

    # create kubeexport.sh
    printf "#!/bin/sh\n\nexport KUBECONFIG=%s\n" "$GEN_DIR/kubeconfig" > "$GEN_DIR/kubeexport.sh"
    chmod +x "$GEN_DIR/kubeexport.sh"

    # explain that user should export KUBECONFIG
    printf "\n\tTo use local kubectl command with multipass k3d cluster, either export or point to kubeconfig"
    printf "\n\n\texport KUBECONFIG=%s\n\n" "$GEN_DIR/kubeconfig"
    printf "\n\tor\n\tsource %s\n" "$GEN_DIR/kubeexport.sh"
    
    source "$GEN_DIR/kubeexport.sh"
}

create_vm () {
    if [ "$(multipass info | grep -c '$MULTIPASS_VM_NAME')" -eq 0 ]; then
        printf "No %s Multipass VM found\nCreating Multipass VM...\n" "$MULTIPASS_VM_NAME"
        multipass launch --name $MULTIPASS_VM_NAME --memory $MEMORY --cpus $CPU_CORES --disk $DISK

        # install docker.io and kubectl
        multipass exec $MULTIPASS_VM_NAME -- sudo apt install -y docker.io
        multipass exec $MULTIPASS_VM_NAME -- sudo snap install kubectl --classic
        multipass exec $MULTIPASS_VM_NAME -- sudo usermod -aG docker ubuntu

        # Open up ports on VM
        multipass exec $MULTIPASS_VM_NAME -- sudo iptables -P FORWARD ACCEPT

        printf "Multipass VM created!\n"
    else
        printf "Skipping Multipass VM Creation...\n"
    fi
}

create_k3d_cluster () {
    MULTIPASS_VM_NAME_ip="$(multipass info $MULTIPASS_VM_NAME | egrep -o 192.168.64.\[0-9\]+)"

    # install k3d
    multipass exec $MULTIPASS_VM_NAME -- bash -c "curl -s https://raw.githubusercontent.com/k3d-io/k3curl -s https://raw.githubusercontent.com/k3d-io/k3curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=v$K3D_VERSION bash"

    # copy k3d yaml to vm
    multipass transfer "$BASE_DIR/configs/k3d/default.yaml" $MULTIPASS_VM_NAME:/home/ubuntu/

    # modify 127.0.0.1 to point to vm ip
    multipass exec $MULTIPASS_VM_NAME -- bash -c "sed -i 's/127.0.0.1/$MULTIPASS_VM_NAME_ip/' /home/ubuntu/default.yaml"

    # start k3d
    multipass exec $MULTIPASS_VM_NAME -- bash -c "K3D_CLUSTER_NAME=$K3D_CLUSTER_NAME K3D_CLUSTER_SERVERS=$K3D_CLUSTER_SERVERS K3D_CLUSTER_AGENTS=$K3D_CLUSTER_AGENTS k3d cluster create --config /home/ubuntu/default.yaml --wait"

    # call create export
    create_export
}

source $BASE_DIR/scripts/system/header.sh -t "Deploying Multipass VM"
# Check if vm exists
if [ "$(multipass list | grep -c $MULTIPASS_VM_NAME)" -eq 0 ]; then

    create_vm
    create_k3d_cluster

else

    # check that VM was stopped
    if [ "$(multipass info $MULTIPASS_VM_NAME | grep -i 'stopped')" ]; then
        printf "%s is stopped, will start....\n" "$MULTIPASS_VM_NAME"
        multipass start $MULTIPASS_VM_NAME
    else
        printf "%s is running, skipping...\n" "$MULTIPASS_VM_NAME"
    fi

fi
