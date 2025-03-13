#!/bin/bash

# This script installs Kubernetes components and uses dialog to offer a GUI
# option for creating a new cluster or joining an existing cluster.
# Run this script as root.

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Install dialog if it is not installed
if ! command -v dialog &> /dev/null; then
    echo "Installing dialog..."
    apt-get update && apt-get install -y dialog
fi

# Install prerequisites for Kubernetes
apt-get update
apt-get install -y apt-transport-https ca-certificates curl

# Add Kubernetes apt repository
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

# Update package list and install Kubernetes components
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Define dialog parameters
HEIGHT=15
WIDTH=50
CHOICE_HEIGHT=4
TITLE="Kubernetes Setup"
MENU="Choose one of the following options:"

OPTIONS=(1 "Create a Cluster"
         2 "Join a Cluster")

# Display the menu using dialog
CHOICE=$(dialog --clear \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

clear

case $CHOICE in
    1)
        # Create a new Kubernetes cluster
        dialog --title "Create Cluster" --msgbox "Initializing Kubernetes cluster. This may take a few minutes..." 10 50
        # Customize the pod network CIDR if needed (here using Flannel's default)
        kubeadm init --pod-network-cidr=10.244.0.0/16
        if [ $? -eq 0 ]; then
            dialog --title "Success" --msgbox "Cluster created successfully." 10 50
            # (Optional) Set up kubeconfig for the current user
            mkdir -p $HOME/.kube
            cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
            chown $(id -u):$(id -g) $HOME/.kube/config
            dialog --title "Note" --msgbox "Don't forget to deploy a pod network (e.g., Flannel, Calico) to make your cluster fully functional." 10 50
        else
            dialog --title "Error" --msgbox "Cluster creation failed. Please check the logs for details." 10 50
        fi
        ;;
    2)
        # Join an existing Kubernetes cluster
        JOIN_CMD=$(dialog --title "Join Cluster" \
                           --inputbox "Enter the full 'kubeadm join' command provided by the cluster admin:" 10 50 \
                           3>&1 1>&2 2>&3 3>&-)
        clear
        if [ -z "$JOIN_CMD" ]; then
            dialog --title "Error" --msgbox "No join command was entered." 10 50
        else
            dialog --title "Joining Cluster" --msgbox "Attempting to join the cluster..." 10 50
            eval "$JOIN_CMD"
            if [ $? -eq 0 ]; then
                dialog --title "Success" --msgbox "Successfully joined the cluster." 10 50
            else
                dialog --title "Error" --msgbox "Failed to join the cluster. Please verify the join command and try again." 10 50
            fi
        fi
        ;;
    *)
        clear
        ;;
esac

# End of script
