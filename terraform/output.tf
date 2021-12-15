output "webhook_url" {
  value = kubernetes_ingress.webhook-ingress.spec[0].tls[0].hosts[0]
}
