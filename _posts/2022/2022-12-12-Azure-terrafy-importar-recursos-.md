---
title: 'Usando Azure Terrafy para importar recursos en Terraform'
author: Victor Silva
date: 2022-12-12T07:23:56+00:00
layout: post
permalink: /azure-terrafy-importar-recursos/
excerpt: 'Dado el uso de Terraform para la definición de recursos, una necesidad que ha surgido en las tareas de gestión de los mismos, es la posibilidad de importar recursos de Azure que se encuentran fuera del estado que terraform mantiene al día. Gracias a esta necesidad llegamos a "Azure Terrafy".'
categories:
  - Terraform
  - IaC
  - Azure
tags:
  - Terraform
  - Azure Terrafy
  - aztfy
  - IaC
---

<div>Esta publicación es parte del Calendario de Adviento Azure 2022, una iniciativa liderada por Héctor Pérez y Luis Beltrán. Revisa <a href="https://elcamino.dev/calendario-adviento-azure-22/">este enlace</a> para conocer más artículos interesantes sobre Azure publicados por varios miembros de la comunidad.</div>{: .notice}

Dado el uso de Terraform para la definición de recursos, una necesidad que ha surgido en las tareas de gestión de los mismos, es la posibilidad de importar recursos de Azure que se encuentran fuera del estado que terraform mantiene al día. Gracias a esta necesidad llegamos a `Azure Terrafy`.

Los recursos que son contemplados dentro de Terrafy son los que hacen parte de [Terraform AzureRM provider](https://github.com/hashicorp/terraform-provider-azurerm)

## Instalación de terraform y aztfy

Si tenemos/usamos `brew`, la instalación se realiza de la siguiente manera:

{% highlight posh%}
brew install terraform
brew install aztfy
{% endhighlight %}

En caso de contar con Windows, podríamos usar [Chocolatey](https://blog.victorsilva.com.uy/chocolatey/) o directamente ir a la web oficial para ver las opciones de instalación disponibles: [Install Terraform](https://developer.hashicorp.com/terraform/downloads).


Para validar que la instalación se ha ejecutado correctamente, simplemente podríamos ejecutar:

{% highlight posh%}
terraform --version
aztfy --version
{% endhighlight %}

Y que ambos comandos devuelvan las versiones correspondientes de las aplicaciones.

## Autenticar contra Azure

Para realizar la autenticación contra Azure es necesario utilizar un `service principal` que tenga los permisos necesarios para poder crear los recursos en nuestra subscription.

Es necesario tener también Azure CLI instalado. Ejecutar lo siguiente con `brew`:

{% highlight posh%}
brew install azure-cli
{% endhighlight %}

O seguir los pasos según corresponda en el siguiente enlace: [How to install the Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli).

### Crear un service principal

Iniciamos la consola de PowerShell y ejecutamos un `az login` para iniciar sesión con nuestro usuario:

{% highlight posh%}
az login
{% endhighlight %}

Ya con la sesión iniciada, listamos las subscriptions disponibles y luego de identificada la que vamos a utilizar, copiamos el id:

{% highlight posh%}
az account list --query "[*].[name,id]"
{% endhighlight %}

Ese id es el que vamos a reemplazar en el sigueinte comando, para crear el service principal y asignarles los permisos correspondientes para este ejemplo:

{% highlight posh%}
$subscriptionId = 'xxxx-xxxxx-xxxxx'
$sp = az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/$subscriptionId" -n TerraformTest | ConvertFrom-Json
{% endhighlight %}


### Crear una storage account

Posterior a la creación del service principal, vamos a crear una storage account para alojar el state de Terraform:

{% highlight posh%}
# Definimos las variables a utilizar
$resourceGroupName = "tfstate"
$storageAccountName = "tfstate" + $(Get-Random)
$containerName = "tfstate"

# Creamos el resource group
az group create --name $resourceGroupName --location eastus

# Creamos la storage account
az storage account create --resource-group $resourceGroupName --name $storageAccountName --sku Standard_LRS --encryption-services blob

# Creamos el blob container
az storage container create --name $containerName --account-name $storageAccountName
{% endhighlight %}

Listo! El siguiente paso es trabajar con Terraform directamente para el despliegue de nuestros recursos necesarios para el escenario de este post.

## Deploy con Terraform

{% highlight posh%}
mkdir terraformTest
cd terraformTest
{% endhighlight %}

Creamos un archivo llamado `main.tf` donde vamos a guardar la configuración de Terraform necesaria para trabajar con el provider de Azure y lo necesario para guardar el state en la storage account creada anteriormente. En el mismo archivo se declara la definición de los recuros que van a hacer parte de la VM a crear:

{% highlight posh%}
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
  backend "azurerm" {
      resource_group_name  = "tfstate"
      storage_account_name = "<storage_account_name>"
      container_name       = "tfstate"
      key                  = "terraform.tfstate"
  }  
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "TerraformTest"
  location = "eastus"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vNet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes       = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "nic" {
  name                = "vm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                = "vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_F2"
  admin_username      = "superadmin"
  admin_password      = "Sup3rP4ss2022@"
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}
{% endhighlight %}

El último paso para tener desplegado los recursos es iniciar el deploy en Terraform: con `terraform init` se inicializa el repositorio, el siguiente comando a ejecutar es `terraform plan` que crea una implementación y valida que esté correctamente definidos los recursos y con todo esto ya estamos en condiciones de ejecutar `terraform apply` con el plan creado para aplicar la configuración definida.

{% highlight posh%}
terraform init
terraform plan -out "plan"
terraform apply "plan"
{% endhighlight %}

<img src="/assets/images/postsImages/AZ_TERRAFY_01.png" class="alignnone">

<img src="/assets/images/postsImages/AZ_TERRAFY_02.png" class="alignnone">

Al final el comando en cuestión se desplegará un output que reflejará el estado de la implementación.

## Modificar recursos por fuera de Terraform

Desde el portal de Azure, navegar hasta la vNET creada, seleccionar **Subnets**, luego seleccionar **+ Subnet** en la parte superior.

Ingresar los valores de nombre y rango de direcciones y click en el botón **Save**.

Perfecto! Ahora el estado de Terraform no tiene actualizado el disco recién creado. Es en este punto que entra en juego Azure Terrafy.

## Actualizar terraform state con aztfy

Para poder actualizar el estado, simplemente se tiene que ejecutar el comando `aztfy rg <opciones> <nombre-rg>` con el nombre del grupo de recursos de Azure que se va a explorar y las opciones de backend:

{% highlight posh%}
aztfy resource-group --backend-type=azurerm --backend-config=resource_group_name=tfstate --backend-config=storage_account_name=tfstate1321790052 --backend-config=container_name=tfstate --backend-config=key=terraform.tfstate TerraformTest
{% endhighlight %}

Y va a comenzar a escanear las diferencias que encuentre para luego agregarlas al main.tf

Y eso es todo! Con esa ejecución se importará en el state de terraform. Para validar simplemente ejecutar:

{% highlight posh%}
terraform state list
{% endhighlight %}

Dando como resultado la lista de los recursos desplegados con la nueva subnet.

Happy scripting!