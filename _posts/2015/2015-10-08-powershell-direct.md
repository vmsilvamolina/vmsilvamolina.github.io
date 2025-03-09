---
title: 'PowerShell Direct - Ejecutar PowerShell en una VM desde el Hyper-V host'
date: 2015-10-08T12:47:04+00:00
author: Victor Silva
layout: post
permalink: /powershell-direct/
dsq_thread_id:
  - "4481906361"
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"738957f617c7";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:116:"https://medium.com/@vmsilvamolina/powershell-direct-ejecutar-powershell-en-una-vm-desde-el-hyper-v-host-738957f617c7";}'
categories:
  - PowerShell
tags:
  - Invoke-Command
  - PowerShell
  - PowerShell Direct
  - PSSession
---
Una de las nuevas características de Hyper-V es PowerShell Direct. Hoy vamos a hablar de qué es y cómo funciona.

PowerShell Direct es un nuevo camino para ejecutar comandos dentro de una máquina virtual desde nuestro host con Hyper-V, independientemente de la configuración de la red o la configuración de administración remota ya sea en el servidor Hyper-V o la máquina virtual.

Básicamente esto quiere decir que **NO ES NECESARIO TENER UNA CONEXIÓN DE RED ENTRE EL HOST Y LA VM** para poder ejecutar comandos de PowerShell. Si la maquina no tiene adaptador de red (o lo tienen deshabilitado) va a funcionar!

Existen 2 maneras de utilizar PowerShell Direct:

  * Crear y cerrar una sesión de PowerShell Direct con los cmdlets de PSSession 
  * Ejecutar un script o comando que utilice el cmdlet Invoke-Command

## Crear y cerrar una sesión de PowerShell Direct con los cmdlets de PSSession

  1. En el Hypervisor, abrir una consola de PowerShell como administrador
  2. Ejecuar uno de los siguientes comandos (PowerShell Direct funciona invocando la VM ya sea por el nombre o por el GUID):
    
    Enter-PSSession -VMName VM01
    
    Enter-PSSession -VMGUID

  3. Ejecutar los comandos que necesitemos ejecutar sobre la VM

  4. Cerrar la PSSession, ejecutando:
    
    Exit-PSSession

## Ejecutar un script o comando que utilice el cmdlet Invoke-Command

Para usar este método, simplemente tenemos que realizar lo siguiente:

    Invoke-Command -VMName PSTest -ScriptBlock { cmdlet }
    

## Por qué es tan genial?

Honestamente, creo que es algo realmente útil y maravilloso! Los que trabajamos creando POCs, demos, probando productos y armando escenarios es bastante tedioso hacerlo, ya que si bien siempre desarrollamos "
parches"
 para estas situaciones, hay casos en los que realmente PowerShell Direct saca ventaja.

Por ejemplo, cuando hacemos cambios a nivel de redes, si la cosa sale mal, si osí tenemos que conectarnos a la VM desde el cliente de Hyper-V, ya que de otra manera no vamos a tener acceso. Lo mismo sucede cuando se aplican políticas de dominio, en las que se modifican, por ejemplo, las relgas de Firewall y ya no podemos administrar remotamente con PowerShell las VMs.

Creo que es una gran mejoría en lo que administración se refiere, y también para implementar productos sin tener que recurrir al **RunOnce** para hacer un enganche de scripts (yo lo hacía bastante!)

Saludos,