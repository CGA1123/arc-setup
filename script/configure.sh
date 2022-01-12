#!/bin/bash

GH_TOKEN="" BROWSER="echo" gh auth login

gh api "/" --jq .current_user_url | awk -F[/:] '{print $4}' > github_host.txt
gh api "/user/memberships/orgs?state=active" > github_orgs.json

# TODO:
# - run arc-setup, output values YAML?
# - run arc helm install
