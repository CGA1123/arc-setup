#!/bin/bash

set -euxo pipefail

helm upgrade \
  --install \
  --repo https://actions-runner-controller.github.io/actions-runner-controller \
  --namespace actions-runner-system \
  --create-namespace \
  --wait \
  -f "${1}" \ # values.yml
  actions-runner-controller \
  actions-runner-controller/actions-runner-controller
