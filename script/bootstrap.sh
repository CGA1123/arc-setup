#!/bin/bash

set -euo pipefail

# tmux, socat
sudo apt-get install socat tmux

# install minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# overmind
wget https://github.com/DarthSim/overmind/releases/download/v2.2.2/overmind-v2.2.2-linux-amd64.gz
gunzip -d overmind-v2.2.2-linux-amd64.gz
chmod +x overmind-v2.2.2-linux-amd64
sudo mv overmind-v2.2.2-linux-amd64 /usr/local/bin/overmind

# helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

minikube addons enable ingress
minikube start
