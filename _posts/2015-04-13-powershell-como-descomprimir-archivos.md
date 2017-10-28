---
id: 767
title: 'PowerShell &#8211; Cómo descomprimir archivos?'
date: 2015-04-13T16:50:36+00:00
author: Victor Silva
layout: post
guid: http://blog.victorsilva.com.uy/?p=767
permalink: /powershell-como-descomprimir-archivos/
dsq_thread_id:
  - "4487759298"
categories:
  - PowerShell
tags:
  - Cmdlets
  - Descomprimir archivos
  - PowerShell
  - Unzip files
---
En PowerShell podemos hacer todo tipo de tareas, es por esto que prentendo compartir una manera de cómo podemos decomprimir archivos con PowerShell.

No necesitamos ningún requerimiento extrar, asi que paso a detallar el procedimiento:

<!--more-->

    # Ubicación del archivo .zip
    Set-Location C:\Scripts\UnzipFiles $Unzip = New-Object -ComObject Shell.Application
    # Nombre del archivo
    $FileName = "Prueba.zip" 
    $ZipFile = $Unzip.NameSpace((Get-Location).Path + "\$FileName") 
    $Destination = $Unzip.namespace((Get-Location).Path) 
    $Destination.Copyhere($ZipFile.items())
    

<img src="https://lh3.googleusercontent.com/-rjzbsVGtq9k/VSwPeYSzfII/AAAAAAAAG5Q/SB51Tz29-L4/w686-h104-no/PS_UnzipFiles_01.png" width="686" height="104" class="alignnone" />

Listo!

Podemos darle una vuelta mas de rosca y generar una función de la siguiente manera:

    function Expand-Zip ($FileName, $Destination) {
        $Unzip = New-Object -ComObject Shell.Application
        $ZipFile = $Unzip.NameSpace($FileName)
        $Final = $Unzip.namespace($Destination)
        $Final.Copyhere($ZipFile.items())
    }
    

Saludos,