---
title: Enviar mails desde Outlook usando PowerShell
date: 2016-03-01T12:30:36+00:00
author: Victor Silva
layout: post
permalink: /enviar-mails-desde-outlook-usando-powershell/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";N;s:10:"author_url";N;s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";N;s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:4:"none";s:3:"url";N;}'
dsq_thread_id:
  - "4719466400"
categories:
  - PowerShell
tags:
  - enviar correos
  - Outlook
  - Outlook.Application
  - PowerShell
  - Send mails
---
Siempre que trabajamos con scripts nos aparecen preguntas o diferentes situaciones que queremos resolver mediante el uso de, en este caso, PowerShell. Así me surgió la pregunta: Cómo enviar mails desde Outlook usando PowerShell?

Podemos usar el siguiente bloque para tal fin:

    $Outlook = New-Object -ComObject Outlook.Application
    $Mail = $Outlook.CreateItem(0)
    $Mail.To = "email@company.com"
    $Mail.Subject = "Soy un asunto"
    $Mail.Body ="Hola!"
    $Mail.Send()
    

Muy fácil,no?

Ahora, para los que quieren entender un poco más sobre como funciona tenemos el siguiente enlace: [Application Object (Oulook)](https://msdn.microsoft.com/en-us/library/office/ff866895.aspx)

También podemos armar una función que simplifique lo anterior:

    Function Send-Email {
    [cmdletbinding()]
    Param (
        [Parameter(Mandatory=$False)][String]$Address,
        [Parameter(Mandatory=$False)][String]$Subject,
        [Parameter(Mandatory=$False)][String]$Body
    )
    
    Begin {
        Clear-Host
    } Process {
        $Outlook = New-Object -ComObject Outlook.Application
        $Mail = $Outlook.CreateItem(0)
        $Mail.To = $Address
        $Mail.Subject = $Subject
        $Mail.Body = $Body
        $Mail.Send()
    }
    }
    
    # Ejemplo de uso
    Send-Email -Address vmsilvamolina@gmail.com -Subject Hola -Body "Esto es un mail!"
    

Aclarar que para que esto funcione es necesario tener una cuenta de correo configurada en nuestro Outlook.

## Multiples destinatarios

Puede pasar que necesitemos enviar ese mail a varios destinatarios diferentes (que no pertenecen a un grupo de distribución :)), para ello vamos a usar un recurso muy simple:

    $Contacts = Get-Content "C:\PowerShell\contacts.txt"
    Foreach ($Contact in $Contacts) {
        Send-Email -Address $Contact
        $i++
    }
    

Saludos,