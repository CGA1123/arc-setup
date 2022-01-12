#!/bin/bash

# Ignore token + browser in codespaces
GH_TOKEN="" BROWSER="echo" gh auth login

if [[ ! -f "github_host.txt" ]]; then
  gh api "/" --jq .current_user_url | awk -F[/:] '{print $4}' > github_host.txt
else
  echo "GitHub Host is already known. (github_host.txt exists)"
  cat github_host.txt
fi

if [[ ! -f "github_orgs.json" ]]; then
  gh api "/user/memberships/orgs?state=active" > github_orgs.json
else
  echo "GitHub Orgs are already known. (github_orgs.json exists)"
fi

if [[ ! -f "arc-values.yml" ]]; then
else
  echo "Actions Runner Controller Chart values are known. (arc-values.yml exists)"
fi

# TODO:
# - run arc-setup, output values YAML?
# - run arc helm install
