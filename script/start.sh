#!/bin/bash

# boot our cluster
minikube start
overmind start -D

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
kubectl apply -f "https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.yaml"

# spin up our GitHub App Manifest Flow server (for app creation)
cat gamf.yml | envsubst | kubectl apply -f -
