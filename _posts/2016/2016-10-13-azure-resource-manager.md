---
title: Azure Resource Manager desde PowerShell
date: 2016-10-13T15:33:49+00:00
author: Victor Silva
layout: post
permalink: /azure-resource-manager/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"6c17b4afc035";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:69:"https://medium.com/@vmsilvamolina/azure-resource-manager-6c17b4afc035";}'
dsq_thread_id:
  - "5633328719"
categories:
  - Azure
  - PowerShell
tags:
  - ARM
  - Azure
  - Azure Resource Explorer
  - Azure Resource Manager
  - PowerShell
---
**Azure Resource Manager** o **ARM** es un paradigma en el que se estructura la administración de Microsoft Azure, por lo que todos los componentes se transforman a recursos; sea una Máquina Virtual, el adaptador de red, la IP pública, sitios web o bases de datos. A su vez, existe una agrupación para estos recursos llamada Resource Group, que permite embolsarlos dentro de una unidad administrativa.

## PowerShell

Obviamente que desde PowerShell vamos a tener un módulo específico en donde disponer de una gran cantidad de Cmdlets para trabajar directamente desde nuetra consola favorita.

Si no tenemos instalado Azure PowerShell, les recomiendo que pasen por el siguiente enlace:

[Instalar y configurar Azure PowerShell](https://docs.microsoft.com/en-us/powershell/azureps-cmdlets-docs/)

Para crear un resource group, simplemente debemos abrir una consola de Azure PowerShell y ejecutar lo siguiente:

{% highlight posh %}
New-AzureRmResourceGroup -Name ResourceGroupTest -Location "South Central US"
{% endhighlight %}

En donde debemos declarar el nombre que vamos a asignar y la locación del mismo. Dentro de la documentación de Microsoft Azure tenemos excelentes ejemplos de como seguir trabajando con ARM desde PowerShell: [Manage Azure resources with PowerShell and Resource Manager](https://docs.microsoft.com/en-us/azure/azure-resource-manager/powershell-azure-resource-manager)

### Crear una VM

Vamos a ver que para crear una VM en Azure desde PowerShell usando ARM no es tan complejo, pero sí es necesario tener en cuenta varios elementos que componen la implementación, como lo son:

  * Virtual Network
  * Public IP
  * Virtual network card
  * Network security group
  * Virtual machine

Con lo anterior voy a compartir un fragmento de código de PowerShell para crear una VM, separado por regiones y comentarios para comprender cada punto de la lista:

## Plantillas JSON

Las plantillas JSON permiten desplegar nuestros recursos de forma declarativa, en donde la propia plataforma es la encargada de todas las tareas de despliegue. Este nuevo recurso presentan un gran nivel de detalle, por lo que tenemos a nuestra disposición una variedad de propiedades para configurar, así como también contamos con un gran repositorio en GitHub (oficial) en el siguiente enlace:

<https://github.com/Azure/azure-quickstart-templates>

En caso que se desee construir una plantilla desde 0, tenemos las [Azure Tools para Visual Studio](https://www.visualstudio.com/es-es/features/azure-tools-vs.aspx) (para cualquiera de las versiones).

<img src="https://al9fmq-ch3302.files.1drv.com/y4m5lW1y4iYPVeC66Q4w6vEFrnIWaltAoSOlHxD63mqpX4Lkla0JU3qTTdF7fzdHtNEuu5K9HeLhpkw65fuWKHQC8tvrsbkpbR5OYlKgsPN__ztMTlMItx1VL9H8vt0DQfbl2Kg9uEF5hv6_zBc0Md36WOaFgn6G6xvfG4QQ_cIoZOIUauNnv4xYAIPL5Lq49OK7x6ZhwuXM095eGYl44qBGA?width=937&#038;height=301&#038;cropmode=none" width="937" height="301" alt="Azure Tools para Visual Studio" class="alignnone size-medium" />

## Azure Resource Explorer

Azure Resource Manager tiene a disposición una herramienta llamada Azure Resource Explorer, que podemos acceder desde el siguiente enlace:

<https://resources.azure.com>

<img src="https://av9gmq-ch3302.files.1drv.com/y4m_UolPE3wNVmDyBNU6hRV91YU9M3D5iTZDV761i66o-cACpmBQlkANkUfir_SAgE1kPL-jWOXbLfHiOsJ7CyllzIeFLh_aY8zozWqj2anIrRb1B4KO2kBFKPV0DeFjtsCfEQQ3x7Jj4DWKqYJc70RmG0NU-KvdKa4gpaqRnIWGZMK0aSTvZRpBvs7mjLMcAK5ZaajRbUiqOJevoVA5xCvQA?width=1363&#038;height=571&#038;cropmode=none" width="1363" height="571" alt="Azure Resource Explorer" class="alignnone size-medium" />

En donde lo primero que nos pide es validarnos con nuestras credenciales de Azure para poder cargar las suscripciones correspondientes. La herramienta nos permite navegar por todos los grupos de recursos agrupados por nuestras suscripciones activas y hacer llamadas a la API REST para realizar operaciones.

Happy scripting!