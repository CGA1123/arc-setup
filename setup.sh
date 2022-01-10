#!/bin/bash

set -euo pipefail

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

echo "Starting up an NGROK tunnel to automate GitHub App creation..."
echo "Press any key to continue."
read -n 1

read -p "ℹ Please input your NGROK authtoken (https://dashboard.ngrok.com/get-started/your-authtoken): " NGROK_TOKEN
ngrok authtoken ${NGROK_TOKEN}

ngrok http -log=stdout -bind-tls=true 1123 > /dev/null &
while ! nc -z localhost 4040; do
  sleep 1
done

NGROK_REMOTE_URL="$(curl --silent http://localhost:4040/api/tunnels | jq -r ".tunnels[0].public_url")"
echo "NGROK Tunnel at: ${NGROK_REMOTE_URL}"

GAMF_URL="${NGROK_REMOTE_URL}" GAMF_EPHEMERAL="true" gamf &

while ! nc -z localhost 1123; do
  sleep 1
done

echo "GitHub App Manifest Flow application started..."

echo "Starting the arc-setup script"
echo "Press any key to continue."
read -n 1

GAMF_HOST="${NGROK_REMOTE_URL}" arc-setup

echo "Terraforming - This will provision new resources to Azure..."
echo "Press any key to continue."
read -n 1

terraform apply -target azurerm_kubernetes_cluster.arc
terraform apply \
  -target helm_release.ingress \
  -target helm_release.cert-manager \
  -target helm_release.arc

terraform apply
