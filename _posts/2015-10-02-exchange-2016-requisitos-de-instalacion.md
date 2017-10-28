---
id: 892
title: Exchange 2016 Requisitos de instalación
date: 2015-10-02T20:12:19+00:00
author: Victor Silva
layout: post
guid: http://blog.victorsilva.com.uy/?p=892
permalink: /exchange-2016-requisitos-de-instalacion/
dsq_thread_id:
  - "4490568402"
categories:
  - Exchange
  - PowerShell
tags:
  - .Net Framework
  - Exchange
  - Exchange 2016
  - MUCM API 4.0
  - PowerShell
  - Requisitos
---
Bajo el lema **_Exchange Server 2016: Forged in the cloud_** tenemos a disposición una mejorada versión de Exchange. Esta versión trae cambios significativos, como por ejemplo, la arquitectura simplificada, el enfoque a la experiencia web de Outlook, la alta disponibilidad de las bases y el énfasis en la colaboración, son algunas de las mejoras que trae la plataforma.

Solamente existen 2 roles en esta versión de Exchange Server: _Mailbox Server_ y _Edge Server_, en lo que a arquitectura se refiere. Esto demuestra el enfoque de simplificar las cosas, permitiendo también gracias a la nueva arquitectura, poder escalar en una implementación on-premise o híbrida, de manera rápida y fácil.

Si bien desde la versión 2013, ya veíamos la evolución de la plataforma hacia lo que es la integración con Office 365, es en ésta versión que se desarrolla en su máxima expresión.

Ahora vamos a ver los requisitos necesarios para poder realizar la instalación de la misma.

## Requisitos para el Mailbox

A continuación dejo un bloque con los comandos necesarios para poder instalar desde la consola de PowerShell los requisitos:

    Install-WindowsFeature AS-HTTP-Activation, Desktop-Experience, NET-Framework-45-Features, RPC-over-HTTP-proxy, RSAT-Clustering, RSAT-Clustering-CmdInterface, RSAT-Clustering-Mgmt, RSAT-Clustering-PowerShell, Web-Mgmt-Console, WAS-Process-Model, Web-Asp-Net45, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Dir-Browsing, Web-Dyn-Compression, Web-Http-Errors, Web-Http-Logging, Web-Http-Redirect, Web-Http-Tracing, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Lgcy-Mgmt-Console, Web-Metabase, Web-Mgmt-Console, Web-Mgmt-Service, Web-Net-Ext45, Web-Request-Monitor, Web-Server, Web-Stat-Compression, Web-Static-Content, Web-Windows-Auth, Web-WMI, Windows-Identity-Foundation -Restart
    

El bloque de código tiene incluido el parámetro **Restart** ya que es necesario. Si lo prefieren, pueden eliminarlo y reiniciar a mano más tarde el servidor.

<img src="https://lh3.googleusercontent.com/Sy4EcDYueU0rKj-xkERUbpPe9lFoH9WTafpMkj_vJUmS-fjxj9ukBTCvcAbhhw3TF9HFEPaQl18_X9SRfSStbjfoQZnq9NzlNg44cmax8G0gVzg52LJ5tX2Zr2a9gqxG2ZnjeAG9d5tF8oVe2JO3hXCNijAV7496yaBoQVE4gVdOS_azsY35korbhekrPWh1mR3MFbo1B4sINjnVor7YR_U-dXpQScaAsczeIcf4tFruOJ6Bh35Odh86OA9OrdAJKV1RT26DW20FMwgy3SEIzSadY2nLjCdR0jTs07tkE9EarrB_MBw59_1jjIhEp-fV3hb_c3akWGkEpC8iq5NdUt3ic7Equgu5J3C19pZbz6XKpbz7tbSi6lg6Pf8-z9UEBuGcoE1rNYW29x8Ei41r8OOIwg1BuwlA901ZL3tu5Japu17YPaQN0mMGPwDwSK0rgEoB5B-EQgZnEJYV2KbaITyOYTeBOCvCHu2VhWjVQN29f2EcJ9pGAaE5lH5t2QQfdrzEkGBL5LnkeVtWyMN_-s8jW3wIuetg_cO8u122-Lk=w874-h197-no" width="874" height="197" class="alignnone" alt="Instalación de requisitos" />

## Requisitos para el Edge Server

El Edge Server no necesita mucha cosa&#8230;

    Install-WindowsFeature ADLDS
    

🙂

## Requisitos generales

No importa si el servidor es Mailbox o Edge, luego de reiniciado el servidor tenemos que instalar lo siguiente (en el orden definido):

  * [.NET Framework 4.5.2](http://go.microsoft.com/fwlink/p/?LinkId=518380)
  * [Microsoft Unified Communications Managed API 4.0, Core Runtime 64-bit](http://go.microsoft.com/fwlink/p/?linkId=258269)

Ahora sí, tenemos todo listo para poder instalar el servidor de Exchange 2016.

## Requisito para las Management Tools

Al igual que Exchange 2013, la consola de administración de Exchange 2016 se consume como recurso web, es decir que para poder acceder a ella no es necesario instalar nada, simplemente accedemos desde el navegador.

En caso de que se quiera instalar la Exchange Management Shell, el único requisito es instalar el .NET Framework 4.5.2 (más arriba el enlace).

Ahora sí, estamos en condiciones de iniciar la instalación del servidor de Exchange!

Saludos,