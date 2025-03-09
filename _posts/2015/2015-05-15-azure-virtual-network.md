---
title: 'Azure Virtual Network'
date: 2015-05-15T23:16:02+00:00
author: Victor Silva
layout: post
permalink: /azure-virtual-network/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"26e686fb512f";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:68:"https://medium.com/@vmsilvamolina/azure-virtual-network-26e686fb512f";}'
dsq_thread_id:
  - "4745396679"
categories:
  - Azure
  - PowerShell
tags:
  - Azure Virtual Network
  - red virtual en azure
  - Set-AzureRmVirtualNetwork
  - VNet
---
Una Azure Virtual Network (red virtual en Azure o VNet) es una representación de nuestra propia red en la nube. Usando VNet se puede controlar la configuración de DNS, definir scopes de DHCP, políticas de seguridad y enrutamiento. También se puede trabajar en subredes y desplegar Azure IaaS Virtual Machines (VMs) e instancias de PaaS, al igual que se haría en las instalaciones de un entorno físico.

En este post vamos a realizar la siguiente configuración:

TestVNet con una reserva 192.168.0.0./16. Esta VNet va a contener las siguientes subredes:

  * FrontEnd, usando el rango 192.168.10.0/24
  * BackEnd, usando el rango 192.168.20.0/24

## Requisitos

Como requisitos tenemos 2 cosas fundamentales que sí o sí debemos cumplir para poder comenzar a trabajar sobre Azure:

Tener una suscripción a Azure; acceder a este [enlace](http://bit.ly/1N1hmrR) para activar una versión trial, en caso de no contar con una.

Contar con el _Azure PowerShell Module_ instalado en el equipo donde se van a ejecutar las configuraciones. Para instalarlo ejecutar los siguientes comandos:

{% highlight posh %}
Install-Module AzureRM
Install-Module Azure
{% endhighlight %}

## Crear la VNet

Primero debemos conectarnos a Azure desde la consola de PowerShell, para hacer ésto vamos a ejecutar:

{% highlight posh %}
Login-AzureRmAccount
{% endhighlight %}

Vamos a generar un Resource Group para este ejemplo, lo vamos a nombrar AzureVNet:

{% highlight posh %}
New-AzureRmResourceGroup –Name “AzureVNet” -Location "West US"
{% endhighlight %}

Creamos la VNet:

{% highlight posh %}
New-AzureRmVirtualNetwork -ResourceGroupName AzureVNet -Name TestVNet -AddressPrefix 192.168.0.0/16 -Location "West US"
{% endhighlight %}

Agregamos los datos de la VNet en una variable para poder usarlos a la hora de crear las subredes:

{% highlight posh %}
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName AzureVNet -Name TestVNet
Add-AzureRmVirtualNetworkSubnetConfig -Name FrontEnd -VirtualNetwork $vnet -AddressPrefix 192.168.10.0/24
Add-AzureRmVirtualNetworkSubnetConfig -Name BackEnd -VirtualNetwork $vnet -AddressPrefix 192.168.20.0/24
{% endhighlight %}

Nos resta aplicar los cambios que realizamos, ya que se encuentran todos dentro de la variable. Para poder aplicarlos debemos ejecutar una simple línea de código, de la siguiente manera:

{% highlight posh %}
Set-AzureRmVirtualNetwork -VirtualNetwork $vnet
{% endhighlight %}

Y con eso sería todo, ya tenemos nuestro esquema de red creado y listo para empezar a trabajar!

Happy scripting!