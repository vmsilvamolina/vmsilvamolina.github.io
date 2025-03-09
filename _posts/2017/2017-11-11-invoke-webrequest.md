---
title: Invoke-WebRequest o el cURL de PowerShell
date: 2017-11-11T15:25:09+00:00
author: Victor Silva
layout: post
permalink: /invoke-webrequest/
categories:
  - PowerShell
tags:
  - cURL
  - HTTP 200
  - Invoke-WebRequest
  - PowerShell
---

Hace algunos días tuve que resolver un pequeño problema que estaba rondando y decidí compartir lo que sé sobre este cmdlet en particular llamado *Invoke-WebRequest*. Así que a modo de introducción voy a señalar que gracias a su uso es posible monitorear sitios web. Si bien este no es su cometido más destacable, con pocas líneas de código podemos realizar cosas muy interesantes, que nos facilitan la tarea tanto de la parte de administración de los servicios web, como también a la hora de implementar una solución o diagnosticar un estado o situación.

Aquellos que vienen del mundo Linux, o tienen conocimiento sobre la consola en general, se deben estar haciendo una idea de que el comando muy similar al viejo cURL ([info aquí](http://en.wikipedia.org/wiki/CURL)). Muy popular porque permite realizar transferencias HTTP, HTTPS, FTP, telnet, etc. En Linux, uno de los usos más habituales es la descarga de archivos o paquetes que se encuentran disponibles en formato HTTP en sistemas sin entorno gráfico.

Trasladando esta situación a entornos Windows, podemos encontrar mayor aplicación en los sistemas core. Pero la mayor particularidad es que a partir de las version 3.0 de PowerShell podemos decir que se incluye cURL en los sistemas Windows, pero siendo éste un alias del comando [Invoke-WebRequest](https://technet.microsoft.com/en-us/library/hh849901.aspx). Para comprobarlo, basta con ejecutar desde nuestra consola de PowerShell el comando curl:

<img src="https://lh3.googleusercontent.com/-owPQrSRFYMo/VM01_l10PDI/AAAAAAAAGxs/tXapJSYd8us/w671-h543-no/PS_CURL_1.png" width="671" height="543" class="alignnone" />

Por ejemplo uno de los usos de este comando es descargar elementos de una web. Si queremos descargar una imagen del sitio _dominio.com_, llamada _imagen.jpg_, simplemente debemos ejecutar el comando:

{% highlight posh %}
Invoke-WebRequest -Uri http://dominio.com/ -OutFile C:\ImagenDescargada.jpg
{% endhighlight %}

Descargando la imagen en la raíz del disco _C:_ con el nombre de _ImagenDescargada.jpg_

Ahora bien, si ejecutamos lo siguiente:

{% highlight posh %}
Invoke-WebRequest -Uri http://blog.victorsilva.com.uy | select StatusCode
{% endhighlight %}    

Nos va a devolver el estado de la web, es decir, si nos devuelve el valor 200, esto indica que la web esta funcionando correctamente. Esto puede ser muy útil a la hora de monitorear varias paginas web, para ver el estado de respuesta, considerando la respuesta anterior de forma similar al "ping".

Una forma más estilizada de presentar estos datos puede ser de la siguiente manera:

{% highlight posh %}
$url = "http://blog.victorsilva.com.uy"

  function Get-WebStatus {
  param(
      $Uri 
  ) 

  $Solicitud = $null 
  $time = try {
      $resultado = Measure-Command {$Solicitud = Invoke-WebRequest -Uri $uri}
      $resultado.TotalMilliseconds
  } catch {
      $Solicitud = $_.Exception.Response 
      $time = -1 
  }

  $resultado = [PSCustomObject] @{ 
      Time = Get-Date; 
      Uri = $uri; 
      StatusCode = [int] $Solicitud.StatusCode; 
      StatusDescription = $Solicitud.StatusDescription; 
      ResponseLength = $Solicitud.RawContentLength; 
      TimeTaken = $time; 
  } 
  $resultado
  }

  Get-WebStatus -Uri $url
{% endhighlight %}

Y como resultado obtenemos:

<img src="https://lh5.googleusercontent.com/-aQYzAcPz2WI/VM1KDURNEpI/AAAAAAAAGyA/L29ya4qU_ck/w407-h140-no/PS_CURL_2.png" width="407" height="140" class="alignnone" />

Happy scripting!