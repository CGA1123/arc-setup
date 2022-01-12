#!/bin/bash

set -euxo pipefail

helm upgrade \
  --install  \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  -- wait \
  ingress-nginx \
  ingress-nginx
