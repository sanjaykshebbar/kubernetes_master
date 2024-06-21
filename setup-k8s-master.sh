#!/bin/bash

set -e

# Update the package list
sudo apt-get update

# Install necessary packages
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Add Docker's APT repository
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Update the package list again
sudo apt-get update

# Install Docker
sudo apt-get install -y docker-ce

# Add the Kubernetes GPG key
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

# Add Kubernetes to the APT repository list
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Update the package list again
sudo apt-get update

# Install Kubernetes components
sudo apt-get install -y kubelet kubeadm kubectl

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Ensure that the required modules are loaded
sudo modprobe overlay
sudo modprobe br_netfilter

# Set up required sysctl parameters, these persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

# Apply sysctl parameters without reboot
sudo sysctl --system

# Install cri-dockerd (Container Runtime Interface for Docker)
sudo apt-get install -y golang-go
git clone https://github.com/Mirantis/cri-dockerd.git
cd cri-dockerd
mkdir bin
go build -o bin/cri-dockerd
sudo cp bin/cri-dockerd /usr/local/bin/

# Create systemd service for cri-dockerd
cat <<EOF | sudo tee /etc/systemd/system/cri-docker.service
[Unit]
Description=CRI Interface for Docker Application Container Engine
Documentation=https://docs.mirantis.com
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/cri-dockerd --container-runtime-endpoint fd:// --network-plugin cni --pod-infra-container-image=k8s.gcr.io/pause:3.5
Restart=always
RestartSec=5
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Create systemd socket for cri-dockerd
cat <<EOF | sudo tee /etc/systemd/system/cri-docker.socket
[Unit]
Description=CRI Docker Socket for the API
PartOf=cri-docker.service

[Socket]
ListenStream=/var/run/cri-dockerd.sock
Service=cri-docker.service
SocketMode=0660

[Install]
WantedBy=sockets.target
EOF

# Reload systemd daemon
sudo systemctl daemon-reload

# Enable and start cri-dockerd service
sudo systemctl enable cri-docker.service
sudo systemctl enable --now cri-docker.socket
sudo systemctl restart cri-docker.service

# Initialize the Kubernetes master node
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Set up kubeconfig for the root user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Apply a pod network add-on (weave)
kubectl apply -f https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')

# Allow scheduling pods on the master node (optional)
# kubectl taint nodes --all node-role.kubernetes.io/control-plane-

echo "Kubernetes master setup is complete."
echo "Run the following command to join worker nodes to the cluster:"
kubeadm token create --print-join-command
