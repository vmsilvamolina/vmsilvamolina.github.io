---
title: 'Azure Private DNS zone fallback to internet'
author: Victor Silva
date: 2025-09-28T21:34:27+00:00
layout: post
permalink: /az-private-dns-fallback/
excerpt: "When working with Azure Private Endpoints across multiple regions, you've likely encountered a common problem: how do you access a resource with a private endpoint from a different region that isn't interconnected with your current virtual network? Microsoft's offer the \"Fallback to Internet\" feature for Azure Private DNS zones solves this challenge elegantly."
categories:
  - Azure
tags:
  - Azure

---
When working with Azure Private Endpoints across multiple regions, you've likely encountered a common problem: how do you access a resource with a private endpoint from a different region that isn't interconnected with your current virtual network? Microsoft's offer the "Fallback to Internet" feature for Azure Private DNS zones solves this challenge elegantly.


## Understanding the Challenge
Private Endpoints provide secure, private connectivity to Azure services by mapping them to private IP addresses within your virtual network. This works seamlessly within a single region or interconnected networks. However, in multi-region scenarios with isolated networks, DNS resolution fails when trying to access a private endpoint from a different region.

### How Private Endpoint DNS Resolution Works
When you create a Private Endpoint for an Azure resource (like a Key Vault or Storage Account), the DNS resolution flow typically works like this:

1. A DNS query for resource-name.vault.azure.net reaches Azure's DNS service
2. The query resolves to a CNAME: resource-name.privatelink.vaultcore.azure.net
3. The Private DNS zone resolves this to the private IP address (e.g., 10.0.0.7)
4. The client receives the private IP and connects through the private endpoint

This works perfectly when the client and the private endpoint are in the same region or connected networks. But what happens when they're not?

## The Problem: Isolated Multi-Region Architectures
Consider this scenario:

* Region A has a virtual network with a Private DNS zone for Key Vault
* Region B has a separate virtual network with its own Private DNS zone
* A VM in Region B needs to access a Key Vault in Region A that's behind a private endpoint
* The networks are not interconnected (due to security policies, overlapping IP ranges, or architectural decisions)

Without Fallback to Internet, the DNS resolution in Region B fails because:

* The query reaches the Private DNS zone in Region B
* No record exists for the Key Vault in Region A
* The DNS query returns empty (NXDOMAIN)
* Access is blocked

Previously, you'd need to implement complex solutions like cross-region VNet peering or custom DNS forwarding. The Fallback to Internet feature provides a much simpler alternative.


## Introducing Fallback to Internet
The Fallback to Internet feature adds a new DNS resolution policy: NxDomainRedirect. When enabled on a Virtual Network Link in your Private DNS zone, it changes the behavior when a DNS query doesn't find a match:
Without Fallback: DNS query fails → NXDOMAIN error → Access denied
With Fallback: DNS query fails → Fallback to public DNS → Resolves to public endpoint → Access via internet (if allowed by firewall)
This allows you to:

* Keep private endpoint connectivity for resources in the same region
* Allow public endpoint access (via firewall rules) for cross-region scenarios
* Avoid complex network peering infrastructure

## Real-World Use Case
Let's say you have:

A centralized Key Vault in Region A with sensitive secrets
Application VMs in multiple isolated regions (B, C, D) that need occasional access
Security requirements that prevent full network interconnection

With Fallback to Internet:

Configure Private Endpoint for the Key Vault in Region A
Enable Fallback to Internet on Private DNS zones in Regions B, C, D
Whitelist the public IP/NAT Gateway IPs from Regions B, C, D on the Key Vault firewall
VMs in Region A access via private endpoint (secure, no internet)
VMs in other regions access via public endpoint (controlled by firewall)

Implementation with Terraform
Let's implement a simple example using Terraform with the AzAPI provider (since the AzureRM provider doesn't support this feature yet).

Prerequisites

{% highlight terraform %}
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}
{% endhighlight %}

Step 1: Create the Private DNS Zone

{% highlight terraform %}
resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.main.name
}
{% endhighlight %}

Step 2: Create Virtual Network Link with Fallback Enabled
Here's where we use the AzAPI provider to enable the Fallback to Internet feature:

{% highlight terraform %}
"azapi_resource" "vnet_link" {
  type      = "Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01"
  name      = "vnet-link-with-fallback"
  parent_id = azurerm_private_dns_zone.keyvault.id
  location  = "global"

  body = jsonencode({
    properties = {
      registrationEnabled = false
      resolutionPolicy    = "NxDomainRedirect"  # Enable fallback
      virtualNetwork = {
        id = azurerm_virtual_network.main.id
      }
    }
  })
}
{% endhighlight %}

Step 3: Create the Private Endpoint

{% highlight terraform %}
"azurerm_private_endpoint" "keyvault" {
  name                = "pe-keyvault"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-keyvault"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault.id]
  }
}
{% endhighlight %}

### Complete Example
Here's a minimal working example:

{% highlight terraform %}
# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-dns-fallback-demo"
  location = "East US"
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-demo"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Subnet for Private Endpoints
resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                       = "kv-demo-${random_string.suffix.result}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  
  # Allow public access with firewall rules
  public_network_access_enabled = true
  
  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = ["YOUR_PUBLIC_IP/32"]  # Add your IPs here
  }
}

# Private DNS Zone
resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.main.name
}

# Virtual Network Link with Fallback
resource "azapi_resource" "vnet_link" {
  type      = "Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01"
  name      = "vnet-link-fallback"
  parent_id = azurerm_private_dns_zone.keyvault.id
  location  = "global"

  body = jsonencode({
    properties = {
      registrationEnabled = false
      resolutionPolicy    = "NxDomainRedirect"
      virtualNetwork = {
        id = azurerm_virtual_network.main.id
      }
    }
  })
}

# Private Endpoint
resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-keyvault"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-keyvault"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault.id]
  }
}

# Helper resources
data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}
{% endhighlight %}


### Testing the Configuration
To verify the Fallback to Internet is working:

{% highlight bash %}
# From a VM in the same VNet (should resolve to private IP)
nslookup kv-demo-xxxxx.vault.azure.net

# From a different region/VNet with fallback enabled (should resolve to public IP)
nslookup kv-demo-xxxxx.vault.azure.net
{% endhighlight %}

You can also use dig for more detailed DNS information:

{% highlight terraform %}
dig kv-demo-xxxxx.vault.azure.net
{% endhighlight %}

Important Considerations

- Security: Always configure firewall rules on your resources when using Fallback to Internet. The feature allows DNS resolution to succeed, but network access still needs to be explicitly allowed.
- Cost: Traffic going through the public endpoint may incur data transfer costs, unlike private endpoint traffic within the same region.
Preview Feature: As of this writing, this feature is still in preview. Check Microsoft's documentation for GA status before using in production.

### Conclusion
The Fallback to Internet feature for Azure Private DNS zones provides an elegant solution for multi-region scenarios where full network interconnection isn't feasible or desired. By allowing DNS resolution to fall back to public endpoints when private resolution fails, it maintains the security benefits of Private Endpoints while providing flexibility for cross-region access patterns.
This feature is particularly valuable when:

Operating isolated regions with centralized resources
Dealing with overlapping IP address spaces
Simplifying network architecture without compromising security
Implementing gradual migrations to fully private networking

Combined with proper firewall configuration, it offers a practical middle ground between fully private and fully public access patterns.

Happy scripting!