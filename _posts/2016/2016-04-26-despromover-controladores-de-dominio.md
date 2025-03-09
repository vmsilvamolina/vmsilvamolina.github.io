---
title: Despromover Controladores de Dominio
date: 2016-04-26T16:39:38+00:00
author: Victor Silva
layout: post
permalink: /despromover-controladores-de-dominio/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:11:"50cb308c4a1";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:82:"https://medium.com/@vmsilvamolina/despromover-controladores-de-dominio-50cb308c4a1";}'
dsq_thread_id:
  - "4792635018"
categories:
  - Active Directory
  - PowerShell
tags:
  - Active Directory
  - Despromover Domain Controller
  - PowerShell
  - Uninstall-ADDSDomainController
format: aside
---
Los que han trabajado con Active Directory, en alguna oportunidad se preguntaron como despromover controladores de dominio. En algunos casos puede ser una tarea muy sencilla&#8230; o puede volverse algo tedioso.

Hoy quiero compartir el procedimiento de como despromover controladores de dominio, usando PowerShell. Vamos a utilizar el cmdlet [Uninstall-ADDSDomainController](https://technet.microsoft.com/en-us/library/hh974714%28v=wps.630%29.aspx):

    Uninstall-ADDSDomainController
    

Luego de ejecutar el comando anterior, nos va a solicitar la clave de administrador local.

Fácil, no? Bueno, puede suceder que necesitemos ingresar el parámetro **_forceremoval_** en caso de querer forzar la acción de despromoción, cuando se complica un poco la tarea 🙂 .

Antes de realizar la despromoción de un Domain Controller, podemos ejecutar:

    Get-ADDomain | Select-Object InfrastructureMaster, RIDMaster, PDCEmulator
    Get-ADForest | Select-Object DomainNamingMaster, SchemaMaster
    

Que nos va a devolver cuales son los servidores que tienen los roles de dominio y bosque, respectivamente. Teniendo identificado donde se encuentra cada rol, vamos a continuar con la ejecución del cmdlet _Uninstall-ADDSDomainController_.

<img src="https://lh3.googleusercontent.com/5w1p1gQwxqFcpgx4_jf2Rt6xzInoKPe45hxE2LKgMNGOkdBJiMqQ8j0FoYwyqPgjJR1fFlouBoW10pcDK1W8Gz4ynHRFyrg1U6rcX70qqtCq4XRPtfJYpTRTs1JUxS_JWPJ16aYWym4mtZs8d2IvjXLz-MH2U4RF8kXfH0JGyj4K-vSXhY_zMEVBcX9a7DztWNRZzHSXMEx1XobRP3KD8uI-OIxyRPEZpyfKBeewyyaYpl5aMpJImeD-Q1Qxpqr-oDXCzdpzpDb7MK0Jx_L0zaMz35dBY9ySUxUGCqNeKD5syL07H91HrR0ezSvkEuX4UgH7I-wgtsez8T-Ekm-2NHmx2S6gSHmY-ubJx4Z4IF-2cEu3S-e_-z005hIv8ncnuJnIHGmyKdqXmLVbLxSPtjFdBlR_d83LFTVK_HbI_8rGrsTZAEvu0nHH8_etmVpO5imj9xvvhlOIzpbkiMNCtpMGBZk1wsrwYnft3iArSL-GfMTN6MbtFYTDpgO6aCEtECfDvLUTGis6yQgRefEZcpQ8DJXGChw6evE2_bTWLnMcl_FhW4fjR2i1rI7SDvJWOBL-=w873-h234-no" width="873" height="234" alt="Uninstall-ADDSDomainController" class="alignnone" />