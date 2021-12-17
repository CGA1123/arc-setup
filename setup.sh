#!/bin/bash

set -euxo pipefail

echo "Logging you into Azure..."
echo "Press any key to continue."
read -n 1
az login -o json > azure_subscriptions.json
az ad signed-in-user show | jq -r .mail > azure_email.txt
az account list-locations > azure_locations.json

echo "Logging you into GitHub..."
echo "Press any key to continue."
read -n 1

gh auth login
gh api "/" --jq .current_user_url | awk -F[/:] '{print $4}' > github_host.txt
gh api "/user/memberships/orgs?state=active" > github_orgs.json

echo "Starting the arc-setup script"
echo "Press any key to continue."
read -n 1

arc-setup

echo "Terraforming - This will provision new resources to Azure..."
echo "Press any key to continue."
read -n 1
terraform apply -target azurerm_kubernetes_cluster.arc
terraform apply \
  -target helm_release.ingress \
  -target helm_release.cert-manager \
  -target helm_release.arc

terraform apply
