#!/bin/bash

set -euxo pipefail

az login -o none
arc-setup
terraform apply -target azurerm_kubernetes_cluster.arc
terraform apply \
  -target helm_release.ingress \
  -target helm_release.cert-manager \
  -target helm_release.arc

terraform apply
