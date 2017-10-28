---
id: 658
title: 'PowerShell &#8211; Invoke-WebRequest'
date: 2014-11-15T20:25:09+00:00
author: Victor Silva
layout: single
guid: http://blog.victorsilva.com.uy/?p=658
permalink: /powershell-invoke-webrequest/
dsq_thread_id:
  - "4505067982"
categories:
  - PowerShell
tags:
  - cURL
  - HTTP 200
  - Invoke-WebStatus
  - PowerShell
---
Hoy quiero hablar de este comando, ya que hace poco me sirivió para monitorear el estado de unas páginas web. Si bien este no es su cometido más destacable, con pocas líneas de código podemos relizar cosas muy interesantes, que nos facilitan la tarea tanto de la parte de administración de los servicios, como también a la hora de implementar una solución o diagnosticar un estado o situación.

Los que trabajan o trabajaron con Linux, se deben estar haciendo una idea de que el comando muy similar al viejo cURL ([mas info](http://en.wikipedia.org/wiki/CURL)). Muy popular porque permite realizar transferencias HTTP, HTTPS, FTP, telnet, etc. En Linux, uno de los usos más habituales es la descarga de archivos o paquetes que se encuentran disponibles en formato HTTP en sistemas sin entorno gráfico.

Trasladando esta situación a entornos Windows, podemos encontrar mayor aplicación es sistemas core. Pero la mayor particularidad es que a partir de las version 3.0 de PowerShell podemos decir que se incluye cURL en los sistemas Windows, pero siendo éste un alias del comando [Invoke-WebRequest](https://technet.microsoft.com/en-us/library/hh849901.aspx). Para comprobarlo, basta con ejecutar desde nuestra consola de PowerShell el comando curl:

<img src="https://lh3.googleusercontent.com/-owPQrSRFYMo/VM01_l10PDI/AAAAAAAAGxs/tXapJSYd8us/w671-h543-no/PS_CURL_1.png" width="671" height="543" class="alignnone" />

Por ejemplo uno de los usos de este comando es descargar elementos de una web. Si queremos descargar una imagen del sitio _dominio.com_, llamada _imagen.jpg_, simplemente debemos ejecutar el comando:

    Invoke-WebRequest -Uri http://dominio.com/ -OutFile C:\ImagenDescargada.jpg
    

Descargando la imagen en la raíz del disco _C:_ con el nombre de _ImagenDescargada.jpg_

Ahora bien, si ejecutamos lo siguiente:

    Invoke-WebRequest -Uri http://blog.victorsilva.com.uy | select StatusCode
    

Nos va a devolver el estado de la web, es decir, si nos devuelve el valor 200, esto indica que la web esta funcionando correctamente. Esto puede ser muy útil a la hora de monitorear varias paginas webpara ver el estado.

Una forma más estilizada de presentar estos datos puede ser de la siguiente manera:

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
    

Y como resultado obtenemos:

<img src="https://lh5.googleusercontent.com/-aQYzAcPz2WI/VM1KDURNEpI/AAAAAAAAGyA/L29ya4qU_ck/w407-h140-no/PS_CURL_2.png" width="407" height="140" class="alignnone" />

Saludos,