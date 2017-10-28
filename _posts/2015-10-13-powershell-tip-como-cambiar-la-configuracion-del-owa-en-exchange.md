---
id: 907
title: 'PowerShell &#8211; Tip: Cómo cambiar la configuración del OWA en Exchange?'
date: 2015-10-13T01:37:54+00:00
author: Victor Silva
layout: single
guid: http://blog.victorsilva.com.uy/?p=907
permalink: /powershell-tip-como-cambiar-la-configuracion-del-owa-en-exchange/
dsq_thread_id:
  - "4511846047"
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"db73bad03107";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:121:"https://medium.com/@vmsilvamolina/powershell-tip-c%C3%B3mo-cambiar-la-configuraci%C3%B3n-del-owa-en-exchange-db73bad03107";}'
categories:
  - Exchange
  - PowerShell
tags:
  - Exchange
  - PowerShell
  - Set-MailboxRegionalConfiguration
---
Hace unos días en Montevideo, Uruguay (ciudad donde vivo), ocurrió un pequeño problema con la hora: en esta fecha se activaba el horario de verano agregando una hora más.

Este año se decició que no se iba a aplicar más este cambio en la hora. Todas las empresas tuvieron errores con este tema, ya que en el Outlook por ejemplo, todas las reuniones estaban una hora más temprano 🙂

La cosa es que la solución más rápida para este problema fue cambiar la zona horaria por otra que sea **GMT-03:00** y que no tenga horario de verano, por ejemplo _Buenos Aires_.

Según el siguiente enlace: [Microsoft Time Zone Indez Values](https://msdn.microsoft.com/en-us/library/ms912391%28v=winembedded.11%29.aspx) que enlista todos los usos horarios, tenemos que Buenos Aires es **_SA Eastern Standard Time_**

Teniendo el formato vamos al servidor de Exchange y desde la Shell de administración de Exchange, ejecutamos:

    Get-Mailbox | Set-MailboxRegionalConfiguration -Language es-UY -TimeZone “SA Eastern Standard Time”
    

El comando anterior realiza el cambio de TimeZone y Language para **_todos_** los usuarios que estén habilitados en Exchange.

En cambio si queremos hacer el cambio para un usuario en particular, debemos ejecutar:

    Set-MailboxRegionalConfiguration -Identity vsilva@at.com.uy -Language es-UY -DateFormat “dd/MM/yyyy” -TimeFormat “HH:mm” -TimeZone “SA Eastern Standard Time”
    

Donde **Identity** permite declarar el valor del usuario al que queremos hacer efectivo el cambio. Además agregamos otros parámetros como DateFormat y TimeFormat para setear la manera en que figuran estos datos

Dejo en enlace a la TechNet para el comando [Set-MailboxRegionalConfiguration](https://technet.microsoft.com/en-us/library/dd351103%28v=exchg.160%29.aspx)

Espero que les sirva la información para resolver algún problema.

Saludos,