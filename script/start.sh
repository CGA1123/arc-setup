#!/bin/bash

# boot our cluster
echo "ℹ Starting up minikube..."
echo "Press any key to continue."
read -n 1
minikube start

echo "ℹ Forwarding our minikube ingress to localhost:80..."
echo "Press any key to continue."
read -n 1
overmind start -D

echo "ℹ Installing nginx-ingress..."
echo "Press any key to continue."
read -n 1
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
echo "Press any key to continue."
read -n 1
kubectl apply -f "https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.yaml"

# spin up our GitHub App Manifest Flow server (for app creation)
echo "ℹ Installing GitHub App Manifest Flow service (for app creation)..."
echo "Press any key to continue."
read -n 1
cat data/gamf.yml | envsubst | kubectl apply -f -