provider "azurerm" {
    features {}
}

terraform {
    backend "azurerm" {
        resource_group_name     = "terraform-rg"
        storage_account_name    = "adonisterraformstorage"
        container_name          = "adonisterraformcontainer"
    }
}

data "azurerm_client_config" "current" {}


# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "resourcegroup" {
    name     = "pipeline_rg"
    location = "westeurope"
}

# Create virtual network
resource "azurerm_virtual_network" "virtualnetwork" {
    name                = "pipeleine_vn"
    address_space       = ["10.0.0.0/16"]
    location            = "westeurope"
    resource_group_name = azurerm_resource_group.resourcegroup.name
}
# Create subnet
resource "azurerm_subnet" "subnet" {
    name                 = "pipeline_subnet"
    resource_group_name  = azurerm_resource_group.resourcegroup.name
    virtual_network_name = azurerm_virtual_network.virtualnetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}


# Create Network Security Group and rule
resource "azurerm_network_security_group" "networksecuritygroup" {
    name                = "pipeline_nsg"
    location            = "westeurope"
    resource_group_name = azurerm_resource_group.resourcegroup.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
    security_rule {
        name                       = "port_8080"
        priority                   = 1111
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "8080"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

    resource "azurerm_subnet_network_security_group_association" "example" {
 	 subnet_id                 = azurerm_subnet.subnet.id
 	 network_security_group_id = azurerm_network_security_group.networksecuritygroup.id
    }

# Create network interface
resource "azurerm_network_interface" "networkinterface" {
    name                      = "pipeline_nic"
    location                  = "westeurope"
    resource_group_name       = azurerm_resource_group.resourcegroup.name

    ip_configuration {
        name                          = "pipeline_nic_config"
        subnet_id                     = azurerm_subnet.subnet.id
        private_ip_address_allocation = "Dynamic"
	public_ip_address_id	      = "/subscriptions/982abf2e-ad19-4895-ae55-8fc1da966f38/resourceGroups/terraform-rg/providers/Microsoft.Network/publicIPAddresses/public-ip-static"
    }
}


# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nsgconnectnic" {
    network_interface_id      = azurerm_network_interface.networkinterface.id
    network_security_group_id = azurerm_network_security_group.networksecuritygroup.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomid" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.resourcegroup.name
    }
    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "storageaccount" {
    name                        = "diag${random_id.randomid.hex}"
    resource_group_name         = azurerm_resource_group.resourcegroup.name
    location                    = "westeurope"
    account_tier                = "Standard"
    account_replication_type    = "LRS"
}

# Create (and display) an SSH key
resource "tls_private_key" "sshkey" {
  algorithm = "RSA"
  rsa_bits = 4096
}

#Insert Public key
resource "azurerm_ssh_public_key" "publickey" {
    name = "pipeline_publickey"
    resource_group_name = azurerm_resource_group.resourcegroup.name
    location = "West Europe"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0jfOt5YGgGtyw6wOE+8ROp7utkcfyDtGW6zR3//L5LdvKxDMr+wOxDGdh9AAtCdHwkypKfDYYMTTe1nAn/615roMtU4YYpUOscoOi5ikSYDPPGMyTN6qFjuemWO2Xk1ljGS+NQEL0YjvD7T/fSNItqid1yU0H4IC7R0kgEiIcJ4LYWCDmG8Huhz4722gsS6xV/leElA2Y+2IRaGT0Jk3GdKptj1gcj86VT34/FUU9OLNnrvy2MqTOYj2n3XAumPfGnYy/AiSyKk8tX78v1wenKvq9M2EmY6y+QpPO9iADgtsZMOWaRCB4kDovWuIF1PZTwZQpybdvQ3QF4DLs6hVz adonis@cc-1649-135dac98-6f74ffbf9c-9bsbk"
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "virtualmachine" {
    name                  = "pipeline_vm"
    location              = "westeurope"
    resource_group_name   = azurerm_resource_group.resourcegroup.name
    network_interface_ids = [azurerm_network_interface.networkinterface.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "OpenLogic"
        offer     = "CentOS"
        sku       = "7.5"
        version   = "latest"
    }

    computer_name  = "pipelinevm"
    admin_username = "azureuser"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "azureuser"
        public_key     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0jfOt5YGgGtyw6wOE+8ROp7utkcfyDtGW6zR3//L5LdvKxDMr+wOxDGdh9AAtCdHwkypKfDYYMTTe1nAn/615roMtU4YYpUOscoOi5ikSYDPPGMyTN6qFjuemWO2Xk1ljGS+NQEL0YjvD7T/fSNItqid1yU0H4IC7R0kgEiIcJ4LYWCDmG8Huhz4722gsS6xV/leElA2Y+2IRaGT0Jk3GdKptj1gcj86VT34/FUU9OLNnrvy2MqTOYj2n3XAumPfGnYy/AiSyKk8tX78v1wenKvq9M2EmY6y+QpPO9iADgtsZMOWaRCB4kDovWuIF1PZTwZQpybdvQ3QF4DLs6hVz adonis@cc-1649-135dac98-6f74ffbf9c-9bsbk"
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.storageaccount.primary_blob_endpoint
    }

    connection {
        type = "ssh"
        user = "azureuser"
        host = "20.73.45.11"
        private_key = tls_private_key.sshkey.private_key_pem
    }

}



