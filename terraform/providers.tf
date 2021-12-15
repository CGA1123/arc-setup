terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "=2.7.1"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "=2.4.1"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.arc.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.arc.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.arc.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.arc.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.arc.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.arc.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.arc.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.arc.kube_config.0.cluster_ca_certificate)
  }
}

