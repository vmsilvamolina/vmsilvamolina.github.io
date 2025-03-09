---
title: Kemp LoadMaster desde PowerShell
date: 2017-12-08T11:21:46
author: Victor Silva
layout: post
permalink: /kemp-desde-powershell/
excerpt: "Actualmente existen una gran oferta en el mundo de networking y seguridad sobre balanceadores de carga, o si queremos ir un poco más allá: Application Delivery Controller. ¿Cuál es la diferencia? Un controlador de entrega de aplicaciones (ADC) es un dispositivo de red específico para tal fin. Su rol es mejorar el rendimiento, la seguridad y capacidad de recuperación de las aplicaciones en la red. Un dispositivo ADC es un balanceador y mucho más."
categories:
  - Kemp LoadMaster
tags:
  - ADC
  - Application Delivery Controller
  - Kemp
  - Kemp LoadMaster 
---

Actualmente existen una gran oferta en el mundo de networking y seguridad sobre balanceadores de carga, o si queremos ir un poco más allá: Application Delivery Controller. ¿Cuál es la diferencia? Un controlador de entrega de aplicaciones (ADC) es un dispositivo de red específico para tal fin. Su rol es mejorar el rendimiento, la seguridad y capacidad de recuperación de las aplicaciones en la red. Un dispositivo ADC es un balanceador y mucho más.

Por más información les comparto la web: [https://kemptechnologies.com/](https://kemptechnologies.com/).

Ahora bien, vamos a lo que nos interesa. La gente de KEMP puso a disposición un módulo para poder administrar Kemp desde PowerShell así que, como se habrán imaginado, el objetivo del post es introducirnos un poco en este módulo.

## Requisitos

Lo primero que debemos obtener es el módulo para importar en PowerShell. La descarga la realizamos de la siguiente URL:

[LoadMaster Powershell API Wrapper](http://kemptechnologies.com/files/assets/tools/KEMP.LoadBalancer.Powershell.zip)

Descomprimir el archivo descargado es lo siguiente que debemos hacer. Luego de ello, vamos a guardar los 4 archivos dentro de una carpeta llamada:

> Kemp.LoadBalancer.PowerShell

A continuación veamos que debemos ejecutar para instalar el módulo con el siguiente bloque de código:

{% highlight posh %}
#Copiamos la carpeta para que todos los usuarios accedan al módulo
cp .\Kemp.LoadBalancer.PowerShell $Env:ProgramFiles\WindowsPowerShell\Modules\ -Recurse
# Save the current value of PSModulePath
$mpath = [Environment]::GetEnvironmentVariable("PSModulePath")
# Add the new path to the $mpath variable
$mpath += ";$Env:ProgramFiles\WindowsPowerShell\Modules\Kemp.LoadBalancer.Powershell"
# Add the paths in $currValue to the PSModulePath value.
[Environment]::SetEnvironmentVariable("PSModulePath", $currValue)
{% endhighlight %}

## Manos a la obra

Ya con todo nuestro escenario listo, vamos a comenzar importando el módulo instalado:

{% highlight posh %}
Import-Module Kemp.LoadMaster.PowerShell
{% endhighlight %}

Nos va a indicar si confiamos en el publisher y listo!

<img src="https://pbqkdq-ch3302.files.1drv.com/y4mkRAj9I67pfUsempQu8bxX-fwNEdVjP7-yDqW9uMaTxd2RbYU6XrHlZOTCauSSjHRHlIuwjkpd48dcEW0URG1uB4ygaWJ7FoQ8R0-gX4uTyqpeDyxrhiX3LnI2QRN5a7x-wCmFkeh2Fe2uqJYiT5RXvRvNy1kMcyERcy_GObHyPEV4iBbW0Obsg37ramMRaREYMVWvRLkk_a36FCYwVvw2w?width=1366&height=394&cropmode=none" width="1366" height="374" alt="Importar módulo de Kemp" class="alignnone size-full" />

Como se ve en la imagen, al finalizar lo expuesto anteriormente, utilicé el comando *Get-Module* a modo de comprobar la correcta importación del módulo.

¿Y qué comandos trae el módulo? Para responder la pregunta anterior vamos a ejecutar:

{% highlight posh %}
Get-command -Module Kemp.LoadMaster.PowerShell
{% endhighlight %}

Para comprobar la conectividad con nuestro balanceador existe un cmdlet llamado *Test-LmServerConnection*:

{% highlight posh %}
Test-LmServerConnection -ComputerName 10.100.10.50 -Port 443 -Verbose
{% endhighlight %}

<img src="https://pbqmdq-ch3302.files.1drv.com/y4mi5ln63eB1J_1rg9aVAR_NC-Fx7HzJD7RjFf1yiwbMuRDb_WHgVX2fGI0HrhY6aVP1Tr6pkxx7jrW-K6yzLBI45uxRZ0ROM14FUihheNSfe4XBc3HF0jPWcyFqur-wq8FANJcqR_BTC7C21YVXIpE0cDaqh6xZ-NU6i-QgyeakLcdehtFmF6v32iFVYzjBvEkZmlOZu6iMhsr5sLhyJrq6w?width=750&height=220&cropmode=none" width="750" height="220" alt="Test-LmServerConnection" class="alignnone size-full" />

### Crear un Virtual Service

El comando para crear un Virtual Service es *New-AdcVirtualService* y vamos a agregarlo usando los siguientes valores:

* Puerto: 443
* IP del Virtual Service: 10.100.10.80

Para ello ejecutaremos:

{% highlight posh %}
New-AdcVirtualService -Port 443 -Protocol tcp -VirtualService 10.100.10.80
{% endhighlight %}

### Agregar un Real Server

Ya con nuestro Virtual Service creado, el siguiente paso es agregar nuestros servidores que brindan la aplicación que queremos balancear. Estos servidores son llamados Real Servers y para agregarlos al Virtual Service es necesario ejecutar el comando 

En nuestro ejemplo, vamos a suponer que tenemos los servidores 10.100.10.15 y 10.100.10.16 para agregar:

{% highlight posh %}
New-AdcRealServer -Port 443 -Protocol tcp -RealServer 10.100.10.15 -RealServerPort 443 -VirtualService 10.100.10.80
  New-AdcRealServer -Port 443 -Protocol tcp -RealServer 10.100.10.16 -RealServerPort 443 -VirtualService 10.100.10.80
{% endhighlight %}

Happy scripting!