---
title: 'PowerShell – Hyper-V: Tareas básicas II'
date: 2014-05-05T21:54:05+00:00
author: Victor Silva
layout: post
permalink: /powershell-hyper-v-tareas-basicas-ii/
dsq_thread_id:
  - "4548487095"
categories:
  - Hyper-V
  - PowerShell
  - Windows Server
tags:
  - Hyper-V
  - PowerShell
  - Live Migration
  - Cmdlets
  - Recursos
  - Virtual Machine
  - Windows Server
---
Siguiendo con el post anterior, en esta oportunidad vamos a crear un script que nos permita realizar comprobaciones antes de hacer Live Migration para que no se generen errores.

Lo primero que vamos a ver es como comprobar los recursos necesarios, como es el caso de la memoria, si no tengo memoria para poder asignar a la maquina que se va a hospedar en el host destino, no voy a poder realizar Live Migration.

## Memoria

Antes de comenzar el live migration, necesitamos asegurarnos de que el host destino tiene la memoria suficiente para poder alojar la maquina virtual, con el siguiente comando:

> Get-VMMemory \[-VMName] <String[]> [-ComputerName <String[]> \] \[ <CommonParameters>\]

Un ejemplo del mismo:

{% highlight posh %}
Get-VMMemory -VMName Server01 -ComputerName HOST2
{% endhighlight %}

Donde HOST2 es el nombre del host destino.

## Procesador

Que pasa si nuestros hosts tienen procesadores de diferente proveedor? No se puede hacer Live Migration por defecto. Lo que debemos hacer es habilitar una opción llamada "Processor Compatibility - Migrate to a Physical computer with a different processor versión" en la configuración de la VM. Es tan simple como ejecutar los siguientes comandos:

Lo primero, detener la maquina virtual para aplicar los cambios:

{% highlight posh %}
Stop-VM –Name VM1
{% endhighlight %}

Ahora, habilitar el modo de compatibilidad:

{% highlight posh %}
Set-VMProcessor VM1 -CompatibilityForMigrationEnabled $true
{% endhighlight %}

## Lectora

Parece muy básico, pero muchas veces trabajando con nuestras maquinas virtuales, dejamos isos montadas, que a la hora de hacer la migración nos hacen saltar errores. Esto sucede, porque la ISO no se encuentra en el host destino. Para no perder tiempo con estas cosas, lo mejor es añadir una simple línea de código que nos permita revisar este pre-requisito por nosotros.

Revisar la lista de ISOS o DVDs conectadas a muestra VM usando:

> Get-VMDvdDrive \[-VMName] <String[]> [-ComputerName <String[]> \] \[-ControllerLocation <Int32> \] \[-ControllerNumber <Int32> \] \[ <CommonParameters>\]

Ahora debemos ejecutar el siguiente comando para remover la ISO o DVD de la VM:

> Set-VMDvdDrive \[-VMName] <String> [[-ControllerNumber] <Int32> \] \[[-ControllerLocation\] <Int32> ] \[[-Path] <String> \] \[-AllowUnverifiedPaths\] \[-ComputerName <String[]> \] \[-Passthru\] \[-ResourcePoolName <String> \] \[-ToControllerLocation <Int32> \] \[-ToControllerNumber <Int32> \] \[ <CommonParameters>\]

Un ejemplo de como sería:

{% highlight posh %}
Set-VMDvdDrive -VMName VM1 -ControllerNumber 1 -ControllerLocation 0 -Path $null
{% endhighlight %}

## Todo junto!

Ahora con lo que pudimos ver vamos a crear un script simple para poder migrar nuestras maquinas!

Partimos de la base que la memoria es suficiente para poder migrar las maquinas.

Lo primero que vamos a hacer es abrir la consola Windows PowerShell ISE y escribir:

{% highlight posh %}
Get-VM -ComputerName Host1 | Out-GridView -Title "Seleccionar una o mas VMs para migrar" -PassThru | Get-VMDvdDrive | where DVDMediaType -ne None | Set-VMDvdDrive -Path $null | Move-VM -DestinationHost Host2 -DestinationStoragePath C:VHDs
{% endhighlight %}

Lo vamos a guardar y al ejecutarlo nos va a desplegar una ventana interactiva que nos permite elegir entre la lista de VMs dentro del Host1 y a su vez de esas maquinas seleccionadas, si tienen algo montado, lo va a desmontar o extraer.

Happy scripting!