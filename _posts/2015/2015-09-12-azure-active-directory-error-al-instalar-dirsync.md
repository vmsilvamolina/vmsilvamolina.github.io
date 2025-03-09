---
title: 'Azure Active Directory - Error al instalar DirSync'
date: 2015-09-12T21:42:25+00:00
author: Victor Silva
layout: post
permalink: /azure-active-directory-error-al-instalar-dirsync/
dsq_thread_id:
  - "4473652421"
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"59d3b7d0ddb4";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:95:"https://medium.com/@vmsilvamolina/azure-active-directory-error-al-instalar-dirsync-59d3b7d0ddb4";}'
categories:
  - Azure
tags:
  - ADFS
  - Asistente para el inicio de sesión
  - Azure
  - Azure Active Directory Sync tool
  - DirSync
  - Error 1605
  - Microsoft Online Services
  - Office365
---
Al implementar _Active Directory Federation Services_ junto con _Windows Azure_, durante el proceso de instalación de _DirSync_ me encontré con el siguiente error:

<img src="https://lh3.googleusercontent.com/Bcb2hRTj7OYA_7ErcR2Uj2u9nzmafm6xgN92RU5UBymf7UM2vW8r_zqmJ_wKc-QPQYU57PtdRjD4WyhFxjnxquUQPGPakligep5yKAoq35XK1nKyst5WEUyVLOM9tQbARxR8eeafyr3rwtf3TIAcCGMmF0QPZiE3R51Qpe3JwIv8OP555TqrH5zHdj6A2skUyy4WtRkoUBi2pPDNjQChE4zQ5_un2zNN970yeVwWl1VGrE6Jowv4aPhQ9ZJMEJPCAG-1T-6XDPOoWVr0lc1ICHoYI1ZzQU-h3P4ux53hrtmLDkeHx2X1fVFI_TzH59u38Lx8UlHNR7Ns2aTOGF2ScanzW3h5DUqkbQcy08RBZsUNo46h7SQ96nUmRyzDBQQZpzhIcvvEVG251ApD9uvHMfPEE-dU-ud2rxjQPoIIWybWYEt7mK58UVVIHUz3XdUV8HOtGDbmhPHkVIxW7QUUTrMQthmPewSPIM9tpT5saPjomwy3Pcq1sB_VtO6EPVmc7oZumZCxaiOcKIC524Ymf0GqKeNw3R--WzRT2ViyHBg=w610-h430-no" width="610" height="430" class="alignnone" />

El error ocurría de la siguiente manera:

El asistente recorría todo el proceso de instalación y llegando casi al final&#8230; error y todo para atrás.

Antes de hacer nada, revisé los requisitos necesarios para la instalación por las dudas que me haya equivocado o me esté faltando algo por hacer. No encontré nada, todo estaba bien.

Me decidí a revisar los eventos de Windows desde el Visor de Eventos, para ver si me daba alguna pista. Pude encontrar el siguiente evento:

<img src="https://lh3.googleusercontent.com/6TYDuW_M9F0jpNZXrGbnGOQGpwTcpiGEEY24VGLEjtq12ge9iiHILPo2yf4EWttNavrbgA7h9jDNFZXj0JCs7TbV7lY7fUV4LuPP1g0pdJKu-6ey4cJwzynIgt5yB9EGAivofWe7891eXnWPIxba_5xTJLXCVIHPLxmKlWx9Mvhti9SflboMno77BN5attQg7wvkH94wfjv4i62Q8ePRpZsZL3zr4qYNRS3UyMeCyHzEEPlWgzy3auoVSktcTL9rsM2eD1UWtZTAdFBvhR4AXezhOqj-E2WO5I0klCcA6a82tBjQmzkycSfqkIcoLuYC1uClVOpxUyY3AIfSEzVQjPNnnwe6UQhTS5ZSZsS6Ho5ceyG6CZvJlL--5eRd9kv6GkGqRpplU6jEWguACxUhC0648_5KjCLtk44SBqWsE2GsJ9ulgl6SwAPlyL8uUQaBQCYU7p1LxVUfamNB4-8kNzCWmcX3RFI8TA6cstXm0dK2rPPXJcq8IVclfE7uK31_1ozrN_qLlOn-Do3jGil-8T4bLH5ZJNGZi01xr_Hfjw8=w908-h502-no" width="908" height="502" alt="error al instalar DirSync" class="alignnone" />

La desinstalación del servicio de **Microsoft Online Services - Ayudante para el inicio de sesión** devolvió el código de error 1605. Intente desinstalar y, si el error persiste, póngase en contacto con el administrador.

Bueno, tenemos un código de error. Luego de buscar por unos minutos el error, pude encontrar el siguiente KB:

[KB2502710](https://support.microsoft.com/en-us/kb/2502710)

En el se detalla el siguiente procedimiento:

  1. Desinstalar: Microsoft Online Services - Ayudante para el inicio de
  2. sesión Desinstalar: Azure Active Directory Sync tool (DirSync)
  3. Instalar: Azure Active Directory Sync tool (DirSync)

<img src="https://lh3.googleusercontent.com/KMkL-bGGbBL4cL7EtpbRrF8EVHERMvJGuu72hIFA7UHXAuKPiKq4Q4nxskAhfv4mTY2YsOn-uWnkI9RRp4H39E49xDU2KmgTHuOOo1fYLHtoj6Jn_U2LnIfT-ZBzXOjsJeAdoub2Z7n008gG9vH0FFhQ-faUsbq3_WV_d7qlBYNDL_W7jXf6EBxxQh9APmEubOo788ffowyh7dhHpFgt59t0KB7kt0Nz4bivBjEs8XGwiSRRf4FJ49tubQRIi8g9b0p-g4VYKQ8M47eKbixKKQD3K2Qlzu-d3-1CsYO70ncwB94CfRDnmrlzMNKBv-KQwDNC4icQSOduouwoIov74OQiFLdIQ03ckt_sV89edXoMO2utOSiubSAIuY1TTzpnVAgA9U4QemmWTCHlv3cT4y96X6CTmNPJQCQseU9uqUsvcpPkBM_VrGrJosICKezclcW_oitz1twzxfzcMWSCNwS0vSYgcuP2K73XpvlVzeFvl3AIJo9zbWZ2RzgrixOtPF9bnBUipV-QP7QT9f6QJuebpHXfbi_9ro4kYTEr2TA=w780-h254-no" width="780" height="254" class="alignnone" />

Listo!

Con el procedimiento anterior en mi caso se pudo resolver. Espero que a ti también te sea de ayuda!

Saludos,