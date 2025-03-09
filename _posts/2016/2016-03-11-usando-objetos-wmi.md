---
title: Usando objetos WMI
date: 2016-03-11T00:25:18+00:00
author: Victor Silva
layout: post
permalink: /usando-objetos-wmi/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";N;s:10:"author_url";N;s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";N;s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:4:"none";s:3:"url";N;}'
dsq_thread_id:
  - "4725265785"
categories:
  - PowerShell
  - Windows
  - Windows Server
tags:
  - Get-WmiObject
  - PowerShell
  - PowerShell WMI
  - cimv2
  - WMI
---
Al momento de aprovechar los beneficios de Powershell usando objectos WMI, estamos interactuando directamente con _WMI namespaces_ y clases. Ahora bien, que es WMI:

> **Windows Management Instrumentation (WMI)** es la fuente principal para administrar los datos y la funcionalidad en equipos locales y remotos que ejecutan los sistemas operativos Microsoft Windows.

Este fragmento de definicón extraído de la [TechNet](https://technet.microsoft.com/es-es/library/cc753534.aspx), nos deja ver que WMI es bastante importante y que es necesario tenerlo en cuenta a la hora de administrar nuestros sistemas. Se pueden obtener los datos de administración de WMI directamente a través de scripts y aplicaciones o a través de herramientas de administración, como pueden ser _System Center Configuration Manager_ o _System Center Operations Manager_.

Como se comentaba en el párrafo anterior, por medio de scripts es posible administrar nuestro sitema operativo y acá les comparto algunos ejemplos de uso:

El primer Cmdlet que vamos a ver es [Get-WmiObject](https://technet.microsoft.com/en-us/library/hh849824.aspx) que permite recolectar la información necesaria dentro de un _namespace_ y _clase_, previamente definido. Por defecto, Get-WmiObject usa el _namespace_ **root\cimv2**, siendo éste el sistema de nombres por defecto utilizado en Windows.

Entonces, vamos a obtener información sobre nuestro equipo:

    Get-WmiObject -Namespace root\cimv2 -Class win32_computersystem
    

<img src="https://lh3.googleusercontent.com/dp8YL2bmUZMaHFB1wxczLp9U4Vj--o6YC7fQW00XAyj3RCVxkmc_BTnHM4OusXmB5Hg8_YFq2NeDhOYAk18rxHEepnW_cdK6gkgBPkGwIrJiTc7WvhMjJ_ynxiWc6DP0FmaSnR28PmJ4SZcSt-jrRC7TReCGVk_t0FFooS9m0Hdi_Dm5b2jM2RZ6RhxPRjxCAMdWnm7OgLpdumk-yXNduvM_ZzaTtnU_lMEh4ZvECfcZmrK6XsfK0gnDFAKIAz66gfuOz5Sd-44YNTl2o4iS_q-YcFtWZV7qdaHRTqenwz5UI21jvdv2m2hHJTUvxpf-ade2nQhRPznLSdL4e9h3NlzkIf9FyPqtnECsKxwU4f3Ysl3FbMTXHB4M0-JBBxcfVgFmlxCyA_m1XyCh-YT-gL13GqbTq-5rSMw1DeY5rGImV16jm4JW6O7mJrdUTqE8dh_OmuE6OY00JzCO1_7og8KVkQfaM0Nxdb1NoQHW_OvJGOtImYJiqspvUJsroBGA8z-r9CIG87cSYI9_qKj0fbMqzu78F1y35EyXlR9seo8h2_WemQeUVEU6lMF6iOpbqTJA=w857-h244-no" width="857" height="244" alt="Usando objectos WMI" class="alignnone" />

Otro ejemplo es usar WMI para obtener información sobre los procesos:

    Get-WmiObject -Class Win32_Process
    

Existe otro Cmdlet similar llamado [Get-CimInstance](https://technet.microsoft.com/en-us/library/jj590758%28v=wps.630%29.aspx) aunque su mayor diferencia es la posibilidad de trabajar remotamente usando una sesión **_CIM_**. Ejecutando el Cmdlet con la clase que usamos en el primer ejempl, vamos a obtener los mismos datos, pero de la siguiente manera:

<img src="https://lh3.googleusercontent.com/JKqTZviy6dDGESC6jdBKXsQSYm8qLUUWzFNoXec3pCccdP-a3jsKs4MPt6TZsgZ9Qbz8LbFw5k5jiBfnacNtZBdEZv3vbGeNqyGLjZv8Ths6QrJtSUZ_1ZNXDatOPaMehCMxF38W1qG3pQ-5MZUa8XbV9bDYGtrLJN3EiNiG9Jc7cBLWW2KZaZ08KmDBIcDPWzp1xNxdgDRKo4q65xJ-vo7A5UX-G_JFxwhpQgGyFsH5AKjdmPee513T2ffUigHrU_MY43VvD-_PRnQH7F5PBIIofA7xWSFfUrCnqMl9YZG2-4tlQaUhVq9ldZihQA1hL2IKdErgRIkXRZi6KUOr9eFlyvo54d3oO6aKrR0_Vu3EUsmuTHwWNeNSrrmjrUlsc7PUDjTuCwHuPy-CVDnPiVct1V36rmOH_P4aHWepgdFP5p41MFq-k7KNGPCLhWzGkzb1fJ38kCtBbX8lWQ0yF2wqhI8IcJWspTJdP0nEtiDPAj53RwXCKXZvWRX-S_xGNkxFpDTdWhIgoTPlsnDbxHRFh-JOWLiKPS3IXz-lQT6t4qQG49I7vYHQn7Hm_BnXy3oR=w857-h175-no" width="857" height="175" alt="Get-CimInstance" class="alignnone" />

Podemos obtener una lista con todas las clases ejecutando:

    Get-WmiObject -list
    

O podemos filtrar en caso de necesitar algo más específico, como podría llegar a ser "
Disk"
, para obtener información de los discos:

    Get-WmiObject -list | where {$_.Name -like "*Disk*"}
    

Donde aparece la clase **Win32_LogicalDisk**, que podemos usarla para obtener el espacio de nuestro disco duro (en mi caso sólo C: ya que no tengo particiones):

    Get-WMIObject -Class Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3}
    

<img src="https://lh3.googleusercontent.com/55vl9geyYHYsxxrllV3NkfflRfqdZg5GQl_XtKiWZpSUeklgIu71Zi6hrL2P2IazpCWCo4AmTC4qI_MqEFd3ylXL1-OODhiA0TfHAb-NqqCGmCD1Lk5oecaeIHG0UqjESLlfe00mRNFzWLdGXLYazLH8s0MMT5juX8hzQJN3xPxMuB-aYfeYyb12Ic42t0I4fivioumFeKCTSSqy79FAYnpe94LsOGW3VtfaGtz7YJCN8VpNyfA2mvF4c7mDfE3jdlsGQ5hQq618ptmczgbItozY76IhNVzLhy4c38pi7pWFja7AMJGxF0vtkJbBpcXg_oK5tEG_TAnnjbGQw86dYHk_CclSG5dss6PvJrZL02VrurlcGfSmiqDXisL-yLQuuFQXZWFbQ9vpGkiJMujy4Bqgk3ebf26ALNo2UjBoRhnH-4DpCbVQ5YL0qNMnpzPzBjMJc4gFXzwVBhE6TT4EEhQhBayu07i5O6QeZOAIUMmiBNTRqn__QocILtpc7Sn59k7ylTuqo_zgFW_uyVLWtzbhh7xkZ3YAcvYTAJJ0PkkqSoCZX_ebkigdk4XsKJW9F7r8=w857-h238-no" width="857" height="238" alt="Win32_LogicalDisk" class="alignnone" />

Existen muchas clases para investigar, lo mejor va a ser que busquen directamente para obtener la información que necesiten.

Saludos,