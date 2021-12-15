#!/bin/bash

set -euxo pipefail

az login -o json > login.json
az ad signed-in-user show > user.json

arc-setup

terraform apply -target azurerm_kubernetes_cluster.arc
terraform apply \
  -target helm_release.ingress \
  -target helm_release.cert-manager \
  -target helm_release.arc

terraform apply
