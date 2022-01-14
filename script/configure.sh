#!/bin/bash

# Ignore token + browser in codespaces
if [[ ! -f "${HOME}/.config/gh/hosts.yml" ]]; then
  GITHUB_TOKEN="" BROWSER="echo" gh auth login
fi

if [[ ! -f "data/github_host.txt" ]]; then
  echo "ℹ Fetching our GitHub Host"
  GITHUB_TOKEN="" gh api "/" --jq .current_user_url | awk -F[/:] '{print $4}' > data/github_host.txt
else
  echo "ℹ GitHub Host is already known. (data/github_host.txt exists)"
fi

if [[ ! -f "data/github_orgs.json" ]]; then
  echo "ℹ Fetching our GitHub Orgs"
  GITHUB_TOKEN="" gh api "/user/memberships/orgs?state=active" > data/github_orgs.json
else
  echo "ℹ GitHub Orgs are already known. (data/github_orgs.json exists)"
fi

if [[ ! -f "data/arc.env" ]]; then
  go run ./cmd/arc-setup
else
  echo "ℹ Actions Runner Controller Chart values are known. (data/arc.env exists)"
fi

echo "ℹ Installing Actions Runner Controller..."
script/subst.sh data/actions-runner-controller.sh | bash -

echo "ℹ Installing Runner Deployment & Autoscaler..."
script/subst.sh data/arc.yml | kubectl apply -f -
