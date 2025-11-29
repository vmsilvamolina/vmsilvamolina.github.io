---
title: 'Hyper-V: Tareas básicas con PowerShell'
date: 2014-05-03T12:44:15+00:00
author: Victor Silva
layout: post
permalink: /powershell-hyper-v-tareas-basicas/
dsq_thread_id:
  - "4484897179"
categories:
  - Hyper-V
  - PowerShell
  - Windows Server
tags:
  - Hyper-V
  - PowerShell
  - Cmdlets
  - Windows Server
---
El módulo de Hyper-V para Windows PowerShell en Windows Server 2012 incluye más de 160 cmdlets para automatizar las tareas de administración de Hyper-V.

A continuación se presentan algunas operaciones básicas que realizamos con frecuencia con Hyper-V y como se podrían recrear por medio de PowerShell.

El uso de estos comandos es el punto de partida, sabiendo que se puede construir una serie de secuencias de comandos complejas utilizando varios cmdlets en diferentes escenarios.

## Habilitar rol de Hyper-V

Lo primero que podemos verificar es si esta instalado el rol, para ello:

{% highlight posh %}
Get-WindowsFeature Hyper-V*
{% endhighlight %}

Y habilitamos el rol de la siguiente manera:

{% highlight posh %}
Install-WindowsFeature –Name Hyper-V –Restart –IncludeAllSubFeature –IncludeManagementTools
{% endhighlight %}

>Este comando reiniciará el servidor, se recomienda guardar los datos antes de ejecutarlo.

## Crear una Maquina Virtual

Lo primero que pensamos cuando hablamos de automatizar tareas en Hyper-V es crear maquinas virtuales.

Vamos a ver que tan fácil es crear uan VM desde PowerShell, con el siguiente comando:

{% highlight plaintext %}
New-VM \[[-Name] <String>\] \[[-MemoryStartupBytes\] <Int64>] -NewVHDPath <String> -NewVHDSizeBytes <UInt64> \[-AsJob\] \[-BootDevice <String> \] \[-ComputerName <String[]> \] \[-Path <String> \] \[-SwitchName <String> \] \[ <CommonParameters>\]
{% endhighlight %}

Aca tenemos un ejemplo para crear una VM :

{% highlight posh %}
New-VM -Name Server01 –MemoryStartupBytes 1GB -NewVHDPath c:Server01.vhd -NewVHDSizeBytes 60GB
{% endhighlight %}

De la misma manera podemos crear un Switch Virtual mediante una sola línea de código, con el siguiente comando:

{% highlight plaintext %}
New-VMSwitch \[-Name] <String> -NetAdapterName <String> [-AllowManagementOS <Boolean> \] \[-ComputerName <String[\]> ] \[-EnableIov <Boolean> \] \[-MinimumBandwidthMode <VMSwitchBandwidthMode> \] \[-Notes <String> \] \[ <CommonParameters>\] 
{% endhighlight %}

Este sería un ejemplo para crear un Switch Virtual:

{% highlight posh %}
New-VMSwitch –Name VSWITCH -NetAdapterName "Ethernet 2"
{% endhighlight %}

## Hyper-V Live Migration:

La migración en vivo con Hyper-V es posible con o sin storage, del mismo modo que si se encuentra en un clúster o no. Se pueden especificar direcciones IP para utilizar exclusivamente en la migración, como también se pueden establecer varias migraciones de maquinas virtuales al mismo tiempo permitiendo una mayor flexibilidad.

Para habilitar Live Migration, simplemente debemos ejecutar:

{% highlight posh %}
Enable-VMMigration
{% endhighlight %}

Para iniciar una migración de una VM, debemos de ejecutar este comando:

{% highlight plaintext %}
Move-VM \[-Name] <String> [-DestinationHost] <String> [-AsJob\] \[-ComputerName <String[\]> ] \[-DestinationStoragePath <String> \] \[-IncludeStorage\] \[-Passthru\] \[-ResourcePoolName <String> \] \[-RetainVhdCopiesOnSource\] \[-SmartPagingFilePath <String> \] \[-SnapshotFilePath <String> \] \[-Vhds <Hashtable[\]> ] \[-VirtualMachinePath <String> \] \[-Confirm\] \[-WhatIf\] \[ <CommonParameters>\]
{% endhighlight %}

Un ejemplo de uso:

{% highlight posh %}
Move-VM –Name Server01 –DestinationHost Host01 –DestinationStoragePath 'C:VMS'
{% endhighlight %}

Además, dependiendo del ancho de banda, se pueden realizar múltiples migraciones en vivo. Esto puede ser controlado ajustando la cantidad de migraciones utilizando la siguiente linea de PowerShell:

{% highlight posh %}
Set-VMHost –MaximumVirtualMachineMigrations [number]
{% endhighlight %}

Happy scripting!