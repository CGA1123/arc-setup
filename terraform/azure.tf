resource "azurerm_resource_group" "arc" {
  name     = var.resource_group
  location = var.location
}

resource "azurerm_kubernetes_cluster" "arc" {
  location            = azurerm_resource_group.arc.location
  resource_group_name = azurerm_resource_group.arc.name
  name                = "${azurerm_resource_group.arc.name}-AKS"
  dns_prefix          = "${azurerm_resource_group.arc.name}-AKS"

  default_node_pool {
    availability_zones     = ["1", "2", "3"]
    enable_auto_scaling    = true
    enable_host_encryption = false
    enable_node_public_ip  = false
    max_count              = 5
    max_pods               = 110
    min_count              = 1
    name                   = "agentpool"
    node_labels            = {}
    node_taints            = []
    orchestrator_version   = "1.20.9"
    os_disk_size_gb        = 128
    os_disk_type           = "Managed"
    tags                   = {}
    type                   = "VirtualMachineScaleSets"
    vm_size                = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}
