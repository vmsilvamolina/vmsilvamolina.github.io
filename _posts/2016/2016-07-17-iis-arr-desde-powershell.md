---
title: IIS ARR desde PowerShell para Skype for Business
date: 2016-07-17T22:47:25+00:00
author: Victor Silva
layout: post
permalink: /iis-arr-desde-powershell/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"584f17646134";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:95:"https://medium.com/@vmsilvamolina/iis-arr-desde-powershell-para-skype-for-business-584f17646134";}'
dsq_thread_id:
  - "5076863211"
categories:
  - PowerShell
  - Skype for Business Server
tags:
  - Application Request Routing
  - ARR
  - IIS
  - IIS ARR
  - PowerShell
  - Reverse Proxy
  - SfB
  - Skype for Business
---
Los que trabajamos con **Skype for Business/Lync** tenemos un rol que, si bien pertenece a la solución, no viene dentro del paquete de implementación: el _Reverse Proxy_. Existen varias soluciones para poder llevar a cabo este rol aunque la más extendida es utilizar un servidor web (IIS). Para ello se debe agregar el módulo de Application Request Routing (ARR) y luego configurar nuestros requerimientos. En este post pretendo compartir cómo implementar un **_reverse proxy_** para utilizar en nuestros proyectos de comunicaciones unificadas utilizando IIS ARR desde PowerShell.

## Instalación de requisitos

Cómo requisito esencial es contar con un Windows Server limpio (instalación nueva), con todos los updates necesarios y las configuraciones pertinentes (por ejemplo: Remote Desktop). Teniendo lo anterior veremos como instalar el rol de IIS y los módulos necesarios desde la consola de PowerShell:

{% highlight posh %}
$MsiFolder = 'C:/msi'
New-Item $MsiFolder -Type Directory | Out-Null
Invoke-WebRequest 'http://download.microsoft.com/download/C/F/F/CFF3A0B8-99D4-41A2-AE1A-496C08BEB904/WebPlatformInstaller_amd64_en-US.msi' -OutFile "$MsiFolder/WebPlatformInstaller_amd64_en-US.msi"
Start-Process "$MsiFolder/WebPlatformInstaller_amd64_en-US.msi" -ArgumentList '/qn' -PassThru | Wait-Process
cd "C:/Program Files/Microsoft/Web Platform Installer"
.\WebpiCmd.exe /Install /Products:'UrlRewrite2,ARRv3_0' /AcceptEULA /Log:$MsiFolder/WebpiCmd.logd
{% endhighlight %}

Vamos a comenzar creando un directorio para alojar nuestros binarios necesarios para la instalación. Posteriormente descargaremos el instalador necesario y como último paso comenzar la instalación de los módulos necesarios (URL Rewrite y ARR 3.0).

## Configuración

Ahora que tenemos el servidor con todo el software necesario instalado, vamos a comenzar a configurar nuestro _Reverse Proxy_. Para ello vamos a hacer una pequeña revisión de lo que necesitamos.

En primer lugar, tenemos que tener definidas las direcciones que necesitamos configurar, siendo las más comunes las siguientes:

  * meet.dominio.com
  * dialin.dominio.com
  * sip.dominio.com
  * lyncdiscover.dominio.com

Éstas URL necesitan direccionarse de los puertos 80 y 443 al 8080 y 4443 respectivamente.

En el siguiente ejemplo vamos a configurar el **farm** que va a manipular la URL **sip.dominio.com** tomando como destino el "
server"
 **PoolSfB.dominio.local**.

Ahora tenemos que repetir lo anterior para cada sitio que necesitemos configurar en nuestro IIS ARR desde PowerShell para finalizar la configuración del Reverse Proxy.

### OWA (WAC)

En caso de contar con un servidor **_Office Web App_**, tendremos que tener en cuenta también la siguiente dirección (por ejemplo):

  * office.dominio.com

Ésta dirección no necesita redireccionar los puertos, simplemente tendremos que agregarla para que permita el tráfico al servidor correspondiente, ejecutando:

<script src="https://gist.github.com/vmsilvamolina/8f1e78fe50f52e602d23e5a52330cf4f.js"></script>

Happy scripting!