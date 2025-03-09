---
title: 'PowerShell - Drivers en Windows'
date: 2015-09-25T21:42:01+00:00
author: Victor Silva
layout: post
permalink: /drivers-en-windows/
dsq_thread_id:
  - "4488032741"
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"cf701197f514";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:76:"https://medium.com/@vmsilvamolina/powershell-drivers-en-windows-cf701197f514";}'
categories:
  - PowerShell
  - Windows
tags:
  - Cmdlet
  - Cmdlets
  - Drivers
  - Export-WindowsDriver
  - Funciones
  - Get-WindowsDriver
  - PowerShell
  - Windows
  - Windows Server
---
Un tema que siempre está en la vuelta de los que somos partidarios del borrón y cuenta nueva: **_Drivers en Windows_**. Los drivers a veces no los manejamos correctamente y tampoco tenemos apoyo para poder ser mas ordenados con este tema.

PowerShell siempre nos respalda y por ello quiero compartir 2 funciones para poder manejar esta situación, como un buen PoShAdmin:

## Export-WindowsDriver

El nombre promete&#8230; y así es, nos permite exportar todos los drivers de terceros (NO Microsoft) a una carpeta destino.

La sintaxis es bien simple:

    Export-WindowsDriver -Online -Destination C:\Drivers
    

Debemos de declarar el parámetro "
Online"
, ya que se debe a la imagen que está corriendo. En caso de que nos encontremos en una situación donde la imagen se encuentre offline, debemos de modificar la sintaxis a algo por el estilo:

    Export-WindowsDriver -Path C:\OfflineImage -Destination C:\Drivers
    

Para los que quieran investigar un poco más sobre este CMdlet, les comparto un enlace a la documentación de Microsoft en la que se habla sobre este comando: [TechNet - Export-WindowsDriver](https://technet.microsoft.com/en-us/library/dn614084.aspx)

## Get-WindowsDriver

Función que nos permite obtener información sobre los drivers de nuestro equipo:

    Get-WindowsDriver –Online -All
    

Siendo el proveedor de los drivers Microsoft u otra empresa (ésto es importante XD ).

Se puede agregar la función Out-GridView para poder obtener la información más ordenada, agregando filtros para reducir los resultados y demás, usando los formularios de Windows:

    Get-WindowsDriver -Online -All | Out-GridView
    

El enlace para este Cmdlet en la documentación oficial de Microsoft es el siguiente: [Get-WindowsDriver](https://technet.microsoft.com/en-us/library/dn376477.aspx)
  
Espero les sirva esta info.

Saludos,