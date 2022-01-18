#!/bin/bash

# boot our cluster
echo "ℹ Starting up minikube..."
minikube start

echo "ℹ Forwarding our minikube port to localhost..."
overmind start -D > /dev/null

echo "ℹ Installing ingress-nginx..."
# setup our ingress
helm upgrade \
  --install  \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --wait \
  ingress-nginx \
  ingress-nginx

# cert-manager
echo "ℹ Installing cert-manager..."
helm install \
  --repo https://charts.jetstack.io \
  --namespace cert-manager \
  --create-namespace \
  --version v1.6.1 \
  --set installCRDs=true \
  --wait \
  cert-manager \
  cert-manager

# spin up our GitHub App Manifest Flow server (for app creation)
echo "ℹ Installing GitHub App Manifest Flow service (for app creation)..."
cat data/gamf.yml | envsubst | kubectl apply -f -
