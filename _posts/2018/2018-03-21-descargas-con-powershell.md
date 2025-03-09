---
title: Descarga de archivos con PowerShell
date: 2018-03-21T13:51:00+00:00
author: Victor Silva
layout: post
permalink: /descargas-con-powershell/
excerpt: "En la oficina he adquirido una fama particular con la automatización de procesos y tareas aburridas. Hace unos días un compañero llegó con una solicitud particular sobre una tarea de administración que él realiza. La tarea en cuestión que debía resolver PowerShell era comprobar de forma local si la versión de un archivo a descargar era la última publicada. De lo contrario, se debía ejecutar la descarga y reemplazar con el archivo nuevo. Ya con la misión definida es hora de ponerse a trabajar."
categories:
  - PowerShell
tags:
  - Download
  - PowerShell
---

En la oficina he adquirido una fama particular con la automatización de procesos y tareas aburridas. Hace unos días un compañero llegó con una solicitud particular sobre una tarea de administración que él realiza. La tarea en cuestión que debía resolver PowerShell era comprobar de forma local si la versión de un archivo a descargar era la última publicada. De lo contrario, se debía ejecutar la descarga y reemplazar con el archivo nuevo. Ya con la misión definida es hora de ponerse a trabajar.

Desglosando el problema tenemos que primero se debe hacer una comprobación local de si el archivo a descargar se encuentra en cierta ruta. Para ello:

{% highlight posh %}
$URL = "https://www.dominio.com/archivo.zip"
  $FilePath = "C:\users\vmsilvamolina\Desktop\Archivos\archivo.zip"
  if (!(Test-Path $FilePath) ) {
      #Descargar
      [void](New-Object System.Net.WebClient).DownloadFile($URL.ToString(), $FilePath)
  } else {
      #Comprobar si son diferentes
  }
{% endhighlight %}

Ahora debemos definir como comprobar si el archivo es igual o diferente, utilizando **HttpWebRequest** de la siguiente manera:

{% highlight posh %}
try {
    $webRequest = [System.Net.HttpWebRequest]::Create($URL);
    $webRequest.IfModifiedSince = ([System.IO.FileInfo]$FilePath).LastWriteTime
    $webRequest.Method = "GET";
    [System.Net.HttpWebResponse]$webResponse = $webRequest.GetResponse()

    $stream = New-Object System.IO.StreamReader($webResponse.GetResponseStream())
    $stream.ReadToEnd() | Set-Content -Path $FilePath -Force 

  } catch [System.Net.WebException] {
    if ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotModified) {
      Write-Host "  $FilePath no se ha modificado, no se descargará..."
    } else {
      $Status = $_.Exception.Response.StatusCode
      $msg = $_.Exception
      Write-Host "  Error al descargar $FilePath : $Status - $msg"
    }
  }
{% endhighlight %}

Si se fijan en la sección de **catch** se observa el estado de WebException para determinar si se descarga el archivo o en su defecto, si se generó un error al intentar descargar.

Con todo lo anterior, podemos armar una función para invocarla, o sumarla a nuestras funciones o módulos  propios, cuando necesitemos realizar esta comprobación:

{% highlight posh %}
function Download-File {
  Param (
    [Parameter(Mandatory=$True)][System.Uri]$URL,
    [Parameter(Mandatory=$True )][string]$FilePath
  )

  #Revisar si el directorio existe
  #System.IO.FileInfo works even if the file/dir doesn't exist, which is better then get-item which requires the file to exist
  if (!(Test-Path ([System.IO.FileInfo]$FilePath).DirectoryName)) {
    [void](New-Item ([System.IO.FileInfo]$FilePath).DirectoryName -Force -Type directory)
  }

  #Revisar si el archivo existe
  if (!(Test-Path $FilePath) ) {
    #Descargar
    [void](New-Object System.Net.WebClient).DownloadFile($URL.ToString(), $FilePath)
  } else {
    try {
      #use HttpWebRequest to download file
      $webRequest = [System.Net.HttpWebRequest]::Create($URL);
      $webRequest.IfModifiedSince = ([System.IO.FileInfo]$FilePath).LastWriteTime
      $webRequest.Method = "GET";
      [System.Net.HttpWebResponse]$webResponse = $webRequest.GetResponse()

      #Read HTTP result from the $webResponse
      $stream = New-Object System.IO.StreamReader($webResponse.GetResponseStream())
      #Save to file
      $stream.ReadToEnd() | Set-Content -Path $FilePath -Force 

    } catch [System.Net.WebException] {
      #Check for a 304
      if ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotModified) {
        Write-Host "  $FilePath not modified, not downloading..."
      } else {
        #Unexpected error
        $Status = $_.Exception.Response.StatusCode
        $msg = $_.Exception
        Write-Host "  Error dowloading $FilePath, Status code: $Status - $msg"
      }
    }
  }
}
{% endhighlight %}

Happy scripting!