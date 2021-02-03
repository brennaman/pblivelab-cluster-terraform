terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "2.40.0"
    }
  }
}

provider "azurerm" {

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  features {}
}

# Create a resource group
resource "azurerm_resource_group" "aks_cluster_group" {
  name     = var.RESOURCE_GROUP
  location = var.REGION_NAME

  tags = {
    Manager = var.tag_manager
    Market = var.tag_market
    Name = var.tag_name
    Project = var.tag_project
  }
}

resource "azurerm_virtual_network" "aks_cluster_vnet" {
  name                = var.VNET_NAME
  location            = azurerm_resource_group.aks_cluster_group.location
  resource_group_name = azurerm_resource_group.aks_cluster_group.name
  address_space       = ["10.0.0.0/8"]

  tags = {
    Manager = var.tag_manager
    Market = var.tag_market
    Name = var.tag_name
    Project = var.tag_project
  }
}

resource "azurerm_subnet" "aks_cluster_subnet" {
  name                 = var.SUBNET_NAME
  resource_group_name  = azurerm_resource_group.aks_cluster_group.name
  virtual_network_name = azurerm_virtual_network.aks_cluster_vnet.name
  address_prefixes     = ["10.240.0.0/16"]
}

resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = "${var.prefix}-k8s"
  location            = azurerm_resource_group.aks_cluster_group.location
  resource_group_name = azurerm_resource_group.aks_cluster_group.name
  dns_prefix          = "${var.prefix}-k8s-ya1hk990"
  kubernetes_version = "1.18.10"
  
  role_based_access_control {
    enabled = true
  }
  

  default_node_pool {
    name           = "system"
    node_count     = 1
    vm_size        = "Standard_DS2_v2"
    vnet_subnet_id = azurerm_subnet.aks_cluster_subnet.id
    type           = "VirtualMachineScaleSets"
    enable_auto_scaling = false
    # min_count = 2
    # max_count = 5
  }

  network_profile {
    network_plugin = "azure"
    dns_service_ip = "10.2.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
    service_cidr = "10.2.0.0/24"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Manager = var.tag_manager
    Market = var.tag_market
    Name = var.tag_name
    Project = var.tag_project
  }

   addon_profile {

     oms_agent {
      enabled = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.cluster_log_analytics_workspace.id
    }

    aci_connector_linux {
      enabled = false
    }

    azure_policy {
      enabled = false
    }

    http_application_routing {
      enabled = false
    }

    kube_dashboard {
      enabled = false
    }
  }
}

resource "azurerm_container_registry" "acr" {
  name                     = "${replace(var.prefix, "-", "")}acr5qlpc"
  resource_group_name      = azurerm_resource_group.aks_cluster_group.name
  location                 = azurerm_resource_group.aks_cluster_group.location
  sku                      = "Standard"

  tags = {
    Manager = var.tag_manager
    Market = var.tag_market
    Name = var.tag_name
    Project = var.tag_project
  }

}

resource "azurerm_log_analytics_workspace" "cluster_log_analytics_workspace" {

  name                = var.cluster_log_analytics_workspace_name
  location            = azurerm_resource_group.aks_cluster_group.location
  resource_group_name = azurerm_resource_group.aks_cluster_group.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    Manager = var.tag_manager
    Market = var.tag_market
    Name = var.tag_name
    Project = var.tag_project
  }

}