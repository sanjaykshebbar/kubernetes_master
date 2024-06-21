#!/bin/bash

# Define variables
INVENTORY_FILE="hosts.ini"
PLAYBOOK_FILE="install-k8s-master.yml"
REPO_URL="https://github.com/sanjaykshebbar/kubernetes_master.git"

# Clone the repository if it doesn't exist
if [ ! -d "kubernetes_master" ]; then
  echo "Cloning repository..."
  git clone $REPO_URL
fi

# Navigate to the repository directory
cd kubernetes_master

# Ensure the playbook and inventory file exist
if [ ! -f "$PLAYBOOK_FILE" ] || [ ! -f "$INVENTORY_FILE" ]; then
  echo "Error: Playbook or inventory file not found in the repository."
  exit 1
fi

# Execute the Ansible playbook
echo "Running Ansible playbook..."
ansible-playbook -i $INVENTORY_FILE $PLAYBOOK_FILE --ask-become-pass

# Exit the script
exit 0
