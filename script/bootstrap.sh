#!/bin/bash

set -euo pipefail

# install tmux, socat
echo "ℹ Installing tmux, socat..."
sudo apt-get -q install -y socat tmux

# install minikube
if [[ ! -f /usr/local/bin/minikube ]]; then
  echo "ℹ Installing minikube..."
  curl -LO --silent https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  chmod +x minikube-linux-amd64
  sudo mv minikube-linux-amd64 /usr/local/bin/minikube
fi

# install overmind
if [[ ! -f /usr/local/bin/overmind ]]; then
  echo "ℹ Installing overmind..."
  wget -q https://github.com/DarthSim/overmind/releases/download/v2.2.2/overmind-v2.2.2-linux-amd64.gz
  gunzip -d overmind-v2.2.2-linux-amd64.gz
  chmod +x overmind-v2.2.2-linux-amd64
  sudo mv overmind-v2.2.2-linux-amd64 /usr/local/bin/overmind
fi

# helm
if [[ ! -f /usr/local/bin/helm ]]; then
  echo "ℹ Installing helm..."
  curl --silent https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "ℹ Exposing our codespaces port publicly..."
gh cs ports visibility 80:public -c "${CODESPACE_NAME}"
