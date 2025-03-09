---
title: 'Crear Hyper-V Containers'
date: 2016-01-01T10:31:54+00:00
author: Victor Silva
layout: post
permalink: /crear-hyper-v-containers/
dsq_thread_id:
  - "4473134480"
categories:
  - Hyper-V
  - PowerShell
  - Windows Server
tags:
  - Containers
  - Get-Container
  - Hyper-V Containers
  - PowerShell
  - Set-Container
  - Windows Server 2016
  - Windows Server Containers
---
Sabemos que existen 2 tipos de _containers_ (gracias a mi post anterior: [Windows Server Containers](http://blog.victorsilva.com.uy/windows-server-containers/)). Hoy me toca hablar de los _Hyper-V Containers_, haciendo especial énfasis en como crear Hyper-V Containers, utilizando siempre PowerShell como principal herramienta de gestión.

Para los que no recuerdan los Hyper-V Containers, tienen como función principal, ampliar el aislamiento proporcionado por los Windows Server Containers mediante la ejecución de cada conteiner en una máquina virtual altamente optimizada. En este tipo de containers, el kernel del _conteiner host_ no se comparte con los contenedores.

### Crear Hyper-V Containers

Ya vimos el comando para crear los Windows Server Containers, pero para este tipo necesitamos declarar el tipo de runtime que se va a ejecutar en nuestro Container, gracias al parámetro **_RuntimeType_** con el valor **_HyperV_**:

    New-Container -Name HVCon -ContainerImageName NanoServer -SwitchName "Virtual Switch" -RuntimeType HyperV
    

Así de fácil creamos un Hyper-V Container!

### Convertir el Container

Una funcionalidad relacionada con la gestión de los Containers es la capacidad de convertir un contenedor, en Hyper-V Container.

> Al momento, solamente se puede convertir el **runtime** de los containers que son **_Nano Server_**.

El procedimiento es bastante sencillo y vamos a comenzarlo creando un container con el _runtime_ por default:

    New-Container -Name DemoCon -ContainerImageName nanoserver -SwitchName NAT
    

Ejecutando el siguiente código, vamos a ver que la propiedad **_RuntimeType_** tiene el valor _default_:

    Get-Container | Select ContainerName, RuntimeType
    

Para hacer la conversión, vamos a usar el comando **_Set-Container_**, ingresando el parámetro _RuntimeType_ con el valor _Hyper-V_

    Set-Container DemoCon -RuntimeType HyperV
    

<img src="https://lh3.googleusercontent.com/u18VPRYbwt925vtLxSDtQeb2YyWMoFCq4Wc1WLpJBoy8QpOG4Ms-6Q6NXCrADNw04eHCXmC-xj6xMLT4uKajwYHvRL8E8DcC4hHnZYlzGXUjYo0vpXVvRCMLK-Erb7hL01nuh8-5ILDjILdVJvD673-lANqyBpa3rDCoctnC3BERAkPnZ27GC8kxEOW51p1jb5RNiozTpgchA_eFUX7s5XHiqlN1fUDPViGcDSDuEkAJ-vS-JzqJ3cT6IgSEHcidnBioVmGf5IbRbJaDGMTY8gS3OD1MWdjsrOu1tiVrKxpX7GaXKCASCbGk7tyXTSDPYRlrGu8cwd9g375BzZQDwtlU4RVW6HPHVy2vhNvbv3zJ7DqrRAMQYkId6f3a2r8ojkIOA21eFqklgSXxGr0m-eG5vJtaURAjysASIwtz5yW2AZsy8FzI87EPDLcd2VixWjbXXDEgurem0U6JfnijCKyMbORzVAaqmaUgmDJ69OQRDT0YQBHav4_In593HHgNuG4jrjaBTqw2Btik_I6lW-DFvN3ataNo1gcPzni7RVv0DR18h8w_6vJ4xtfz4-z1nKTX=w1004-h544-no" width="1004" height="544" alt="Hyper-V Container - Conversión" class="alignnone" />

En el post anterior ([Crear Windows Server Containers](http://blog.victorsilva.com.uy/crear-windows-server-containers/)) dejo un ejemplo de cómo crear una "
web"
 y ejecutarla en el container.

Ahora queda en ustedes seguir probando funcionalidades y quedar a la espera de las nuevas características que van a ir surgiendo.

Saludos,