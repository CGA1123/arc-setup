#!/bin/bash

# Ignore token + browser in codespaces
GITHUB_TOKEN="" BROWSER="echo" gh auth login

if [[ ! -f "github_host.txt" ]]; then
  GITHUB_TOKEN="" gh api "/" --jq .current_user_url | awk -F[/:] '{print $4}' > github_host.txt
else
  echo "GitHub Host is already known. (github_host.txt exists)"
fi

if [[ ! -f "github_orgs.json" ]]; then
  GITHUB_TOKEN="" gh api "/user/memberships/orgs?state=active" > github_orgs.json
else
  echo "GitHub Orgs are already known. (github_orgs.json exists)"
fi

if [[ ! -f "arc-values.yml" ]]; then
  go run ./cmd/arc-setup
  echo "get values"
else
  echo "Actions Runner Controller Chart values are known. (arc-values.yml exists)"
fi

# TODO:
# - run arc-setup, output values YAML?
# - run arc helm install
