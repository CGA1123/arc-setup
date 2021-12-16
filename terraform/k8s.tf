resource "kubernetes_namespace" "arc-runners" {
  metadata {
    name = "arc-runners"
  }
}

resource "kubernetes_manifest" "runner-deployment" {
  depends_on = [helm_release.arc]

  manifest = {
    "apiVersion" = "actions.summerwind.dev/v1alpha1"
    "kind"       = "RunnerDeployment"
    "metadata" = {
      "name"      = "arc-runners"
      "namespace" = kubernetes_namespace.arc-runners.metadata[0].name
    }

    "spec" = {
      "template" = {
        "spec" = {
          "ephemeral"    = true
          "organization" = var.organization
          "group"        = var.runner_group
          "labels"       = ["arc-runner"]
        }
      }
    }
  }
}

resource "kubernetes_manifest" "runner-autoscaler" {
  manifest = {
    "apiVersion" = "actions.summerwind.dev/v1alpha1"
    "kind"       = "HorizontalRunnerAutoscaler"
    "metadata" = {
      "name"      = "arc-webhook-autoscaler"
      "namespace" = kubernetes_namespace.arc-runners.metadata[0].name
    }
    "spec" = {
      "maxReplicas" = 10
      "minReplicas" = 0
      "scaleTargetRef" = {
        "name" = kubernetes_manifest.runner-deployment.manifest.metadata.name
      }
      "scaleUpTriggers" = [
        {
          "duration"    = "30m"
          "githubEvent" = {}
        },
      ]
    }
  }
}

resource "kubernetes_manifest" "clusterissuer_letsencrypt" {
  depends_on = [helm_release.cert-manager]

  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name" = "letsencrypt"
    }
    "spec" = {
      "acme" = {
        "email" = var.letsencrypt_email
        "privateKeySecretRef" = {
          "name" = "letsencrypt"
        }
        "server" = "https://acme-v02.api.letsencrypt.org/directory"
        "solvers" = [
          {
            "http01" = {
              "ingress" = {
                "class" = "nginx"
              }
            }
          },
        ]
      }
    }
  }
}

resource "kubernetes_ingress" "webhook-ingress" {
  depends_on             = [helm_release.ingress]
  wait_for_load_balancer = true

  metadata {
    name      = "arc-webhook-ingress"
    namespace = kubernetes_namespace.arc-system.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"             = "letsencrypt"
      "kubernetes.io/ingress.class"                = "nginx"
      "nginx.ingress.kubernetes.io/rewrite-target" = "/$1"
      "nginx.ingress.kubernetes.io/use-regex"      = "true"
    }
  }

  spec {
    rule {
      host = "${var.dns_prefix}.${azurerm_resource_group.arc.location}.cloudapp.azure.com"
      http {
        path {
          path = "/(.*)"
          backend {
            service_name = "actions-runner-controller-github-webhook-server"
            service_port = 80
          }
        }
      }
    }

    tls {
      hosts       = ["${var.dns_prefix}.${azurerm_resource_group.arc.location}.cloudapp.azure.com"]
      secret_name = "webhook-tls-secret"
    }
  }
}
