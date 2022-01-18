set -euo pipefail

helm upgrade \
  --install \
  --repo https://actions-runner-controller.github.io/actions-runner-controller \
  --namespace actions-runner-system \
  --create-namespace \
  --wait \
  --set githubEnterpriseServerURL="${ARC_GITHUB_ENTERPRISE_URL}" \
  --set githubWebhookServer.secret.github_webhook_secret_token="${ARC_GITHUB_APP_WEBHOOK_SECRET}" \
  --set authSecret.github_app_id="${ARC_GITHUB_APP_ID}" \
  --set authSecret.github_app_installation_id="${ARC_GITHUB_APP_INSTALLATION_ID}" \
  --set-file authSecret.github_app_private_key="${ARC_GITHUB_APP_PEM_FILE_PATH}" \
  -f data/arc-values.yml \
  actions-runner-controller \
  actions-runner-controller
