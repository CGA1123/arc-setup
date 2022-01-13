#!/bin/bash

set -euo pipefail

# install tmux, socat
sudo apt-get install socat tmux

# install minikube
if [[ ! -f /usr/local/bin/minikube ]]; then
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  chmod +x minikube-linux-amd64
  sudo mv minikube-linux-amd64 /usr/local/bin/minikube
fi

# install overmind
if [[ ! -f /usr/local/bin/overmind ]]; then
  wget https://github.com/DarthSim/overmind/releases/download/v2.2.2/overmind-v2.2.2-linux-amd64.gz
  gunzip -d overmind-v2.2.2-linux-amd64.gz
  chmod +x overmind-v2.2.2-linux-amd64
  sudo mv overmind-v2.2.2-linux-amd64 /usr/local/bin/overmind
fi

# helm
if [[ ! -f /usr/local/bin/helm ]]; then
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

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

# spin up our GitHub App Manifest Flow server (for app creation)
cat gamf.yml | envsubst | kubectl apply -f -

gh cs ports visibility 80:public -c "${CODESPACE_NAME}"
