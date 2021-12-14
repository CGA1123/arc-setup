resource "kubernetes_namespace" "arc-system" {
  metadata {
    name = "arc-system"
  }
}

resource "kubernetes_namespace" "cert-manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "kubernetes_namespace" "nginx-ingress" {
  metadata {
    name = "nginx-ingress"
  }
}

resource "helm_release" "ingress" {
  repository = "https://kubernetes.github.io/ingress-nginx"
  name       = "nginx-ingress"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace.nginx-ingress.metadata[0].name

  set {
    name  = "controller.replicaCount"
    value = "2"
  }

  set {
    name  = "controller.service.annotations.\"service\\.beta\\.kubernetes\\.io/azure-dns-label-name\""
    value = var.dns_prefix
  }
}

resource "helm_release" "cert-manager" {
  repository = "https://charts.jetstack.io"
  name       = "cert-manager"
  namespace  = kubernetes_namespace.cert-manager.metadata[0].name
  chart      = "cert-manager"
  version    = "1.6.1"

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "helm_release" "arc" {
  depends_on = [helm_release.cert-manager]

  repository = "https://actions-runner-controller.github.io/actions-runner-controller"
  name       = "actions-runner-controller"
  chart      = "actions-runner-controller"
  namespace  = kubernetes_namespace.arc-system.metadata[0].name
  version    = "0.15.1"

  values = [
    "${file("arc-values.yaml")}"
  ]

  set {
    name  = "githubEnterpriseServerURL"
    value = var.enterprise_url
  }

  set {
    name  = "githubWebhookServer.secret.github_webhook_secret_token"
    value = var.webhook_secret
  }

  set {
    name  = "authSecret.github_app_id"
    value = var.app_id
  }

  set {
    name  = "authSecret.github_app_installation_id"
    value = var.installation_id
  }

  set {
    name  = "authSecret.github_app_private_key"
    value = file(var.private_key)
  }
}
