---
id: 328
title: 'PowerShell: Consultar espacio en discos locales'
date: 2014-04-27T14:25:11+00:00
author: Victor Silva
layout: post
guid: http://vmsilvamolina.wordpress.com/?p=328
permalink: /powershell-consultar-espacio-en-discos-locales/
dsq_thread_id:
  - "4472137083"
categories:
  - PowerShell
  - Windows Server
tags:
  - Cmdlets
  - Espacio en disco
  - PowerShell
---
Lo que vamos a ver en esta oportunidad es como sacer un pequeño reporte del estado de nuestros discos. <!--more--> Primero vamos a habrir la Windows Powershell ISE, para armar nuestro script. Y escribimos:

    Get-WMIObject  -Class Win32_LogicalDisk | Where-Object {$\_.DriveType -eq 3}  `
     | Select-Object @{n="Unidad";e={($\_.Name)}}, 
                    @{n="Etiqueta";e={($\_.VolumeName)}}, 
                    @{n='Tamaño (GB)';e={"{0:n2}" -f ($\_.size/1gb)}}, 
                    @{n='Libre (GB)';e={"{0:n2}" -f ($\_.freespace/1gb)}}, 
                    @{n='% Libre';e={"{0:n2}" -f ($\_.freespace/$_.size*100)}}
    

Lo que hacemos con estas lineas es desde el comando **Get-WMIObject** buscar en la clase **Win32_LogicalDisk** los datos. En este caso seleccionamos los objetos (Discos) que son del tipo local (**Where-Object {$_.DriveType -eq 3}**). Vamos a guardar este archivo con el nombre, por ejemplo, de DiskInfo.ps1.

Ahora ejecutamos una consola de PowerShell, vamos a la ruta donde guardamos el archivo (en caso de guardarlo en la raiz del disco **C:** sería:

    cd C: 
    

Y escribimos:

    .DiskInfo.ps1 
    

Y tendriamos como resultado obtenemos lo siguiente:

<img class="alignnone" src="https://lh4.googleusercontent.com/-vF7ksa2i5aM/U2hGhIe-naI/AAAAAAAAEXg/TBWlv2o9ZqU/w270-h184-no/DiskInfo.png" alt="" width="270" height="184" />

En mi caso, tengo solamente una unidad con sus respectivos datos.

Saludos,