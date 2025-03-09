---
title: 'Windows Server Containers'
date: 2015-12-24T09:16:32+00:00
author: Victor Silva
layout: post
permalink: /windows-server-containers/
dsq_thread_id:
  - "4483865845"
categories:
  - Hyper-V
  - PowerShell
  - Windows Server
tags:
  - Cmdlet
  - Containers
  - Host
  - Hyper-V
  - PowerShell
  - Windows Server 2016
  - Windows Server Containers
  - Windows Server TP4
---
### Windows Server Containers?

> Sistema operativo isolado, portable y con recursos controlados.

Si estuvieras dentro de un container, se vería como si estuvieras dentro de un equipo físico recién instalado o una máquina virtual, para tener un referencia de lo que ya conocemos&#8230;

Los Windows Server Containers son un método ligero de virtualización del SO, que es usado para separar las aplicaciones o servicios de otros servicios que se ejecutan en el mismo host. Es un lugar aislado donde la aplicación puede ejecutarse sin afectar al sistema y el sistema no puede afectar a la aplicación.

Son la siguiente evolución de la virtualización. Para que esto pueda realizarse, cada contenedor tiene su propio punto de vista del sistema operativo, su propio sistema de archivos, registro y direcciones IP.

Ahora bien, que sucede con los containers de Linux y Windows Server. Son similares? La respuesta es que ambos implementan tecnologías similares dentro de su respectivo SO y kernel. La diferencia proviene de la plataforma y las cargas de trabajo que se ejecutan dentro de los contenedores. Cuando un cliente está utilizando un container de Windows Server, puede integrarse con las tecnologías existentes de Windows como .NET, ASP.NET, PowerShell, etc.

### Tipos de Windows Server Containers

Existen dos tipos de contenedores en Windows Server:

**Windows Server Containers –** Proporcionan un aislamiento de aplicaciones a través de procesos y tecnología de aislamiento de namespace. Un conteiner de Windows Server comparte el kernel con el _conteiner host_ y con todos los conteiners que se estén ejecutando en el mismo host.

**Hyper-V Containers –** El mayor cometido es ampliar el aislamiento proporcionado por los Windows Server Containers mediante la ejecución de cada container en una máquina virtual altamente optimizada. En este tipo de containers, el kernel del _conteiner host_ no se comparte con los Hyper-V Containers.

### Cómo trabajamos con los Windows Server Containers?

Los Windows Server Containers se pueden utilizar para desplegar rápidamente muchas aplicaciones aisladas de un único sistema. Este post pretende demostrar el despliegue y la gestión de los containers utilizando PowerShell como herramienta principal.

Vamos a ver como crear una app desde cero, siendo ésta, el clásico "
hola mundo"
, mostrando todos los elementos del proceso; crear imagenes de contenedores, trabajar con carpetas compartidas, y gestionar el ciclo de vida para poder tener una comprensión básica del despliegue y gestión de los mismos.

Este tutorial detalla la gestión de ambos tipos de containers, considerando que cada tipo de container tiene sus requisitos propios:

**Windows Server Containers -** Un Windows Container Host corriendo Windows Server 2016 Core.

**Hyper-V Containers -** Un Windows Container Host con Nested Virtualization habilitado. Windows Server 2016 ([enlace de descarga](https://aka.ms/tp4/serveriso))

### Primeros pasos

Para poder ejecutar los siguientes ejemplos, es necesario cumplir con lo siguiente:

  * Windows 10 build 1056+ / Windows Server Technical Preview 4+
  * Rol de Hyper-V habilitado y permisos de administrador del host.
  * 20GB de espacio disponible.

## Configurar el Container Host en una VM

Lo primero, ejecutar una consola de PowerShell como administrador, o de lo contrario, ejecutar lo siguiente:

    Start-Process powershell -Verb runas
    

Lo siguientes es ejecutar un script que se puede descargar del siguiente enlace: [Configuration Script](https://aka.ms/tp4/New-ContainerHost). Pero para que funcione correctamente es necesario contar con un Switch externo en nuestro host. Para comprobar si realmente existe uno ya creado (y, obviamente desde la consola) ejecutamos:

    Get-VMSwitch | where {$_.SwitchType –eq “External”}
    

Habiendo confirmado que realmente existe el Switch, podemos pasar a ejcutar lo siguente:

    wget -uri https://aka.ms/tp4/New-ContainerHost -OutFile c:\New-ContainerHost.ps1
    cd\
    .\New-ContainerHost.ps1 –VmName Server01 -WindowsImage ServerDatacenterCore -Hyperv
    

Donde **_Server01_** es el host donde estamos trabajando (reemplazar este cambio).

Al ejecutar lo anterior, vamos a tener que ingresar la contraseña del administrador y aceptar los términos de licencia.

Después de pasar el paso anterior, la secuencia anterior va a comenzar a descargar achivos y configurar los componentes necesarios. Este proceso puede tardar un tiempo considerable debido a la descarga.

Si ya tienen la ISO de Windows Server Technical Preview 4 descargada, es posible "
obviar"
 la descarga situando la ISO con el nombre **_WindowsServerTP4.ISO_** en la ruta **_C:\Users\Public\Documents\Hyper-V\Virtual hard disks_**.

<img src="https://lh3.googleusercontent.com/rJBjnV0B-Myld911x708GRNfjKTJEkeVmaxq3Al8v7cQjYCrOhaHVdVqlg8Af2S2MuSrdWTJzyIKo2_ZPiKFnqIESdxopqRlzaBzWC2tW8iLAjbG20QT4wTQMrjbf7882JsxcPjfGhoSDdKPtBN-wiY8-2csxN3eQCDaLoq6T9Do9v36arduocUImAJ1XSmpeb9TKVR-kI-rk8ElHHRQrmXlRRJjC3SyMG8Mvh4CXlr8TUZtMUPNSmMUCyUnEehaDLB4bK16JhGQOyQdlbgMqURRqLDMrjge3zUgwZ1SyjX9yN-uW8rNl0P3gy2hUwi6giHEzHWx-KaHHZjh0PgbEaU8FRpYFFGNjCDiuBQ_EEETnFWWdzU-BFmF9aJQFMGWMKiJWntNZuL4LdMo9e61kToJRt81ZNrQoizFXIzrb25hCReQCBoK9Zpd5S5uKfmJBEI6ApndUmxkeZXsOYAZJr9cVc3_tZ4Ns7SQsBUm7bBqgkCLKYlnOY3ie0Vwt1lsHuIKHAKoekIXUy2sjG2ltBEarUMFTuPkFG5WkCmwEInm1A2bkb_8Obso1Ar4k1nAf7fF=w1039-h635-no" width="1039" height="635" alt="Ejecutando New-ContainerHost.ps1" class="alignnone" />

Al finalizar el proceso, va a ser posible crear y administrar Windows Containers y Windows Containters Images, tanto con PowerShell como con Docker.

Finalizado el script de configuración, iniciar sesión en la VM con la contraseña especificada durante el proceso de configuración y comprobar que tiene una dirección IP válida.

En en siguiente post vamos a ver como crear un Windows Server Container.

Saludos,