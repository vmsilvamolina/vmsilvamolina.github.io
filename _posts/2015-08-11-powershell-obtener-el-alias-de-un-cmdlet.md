---
id: 859
title: 'PowerShell: Obtener el alias de un cmdlet'
date: 2015-08-11T02:10:10+00:00
author: Victor Silva
layout: post
guid: http://blog.victorsilva.com.uy/?p=859
permalink: /powershell-obtener-el-alias-de-un-cmdlet/
dsq_thread_id:
  - "4581339142"
categories:
  - PowerShell
tags:
  - Cmdlets
  - gal
  - Get-Alias
  - PowerShell
---
En alguna oportunidad nos vamos a encontrar algún ejemplo de código el cuál se encuentra utilizando un alias. El **alias** es una forma abreviada del nombre del cmdlet. Un ejemplo es **_gcm_**, que es el alias de **_Get-Command_**.

Ahora bine, como hacemos nosotros para saber el alias de un cmdlet. Para mí, hay 2 opciones bien claras:

1 Nos aprendemos de memoria todos los alias que existen de PowerShell
  
2 Prestan atención a un tip que les voy a compartir 🙂

Yo creo que no hay dudas de cuál es la opción correcta: lo mejor es empezar por la TechNet que tiene todo!

El Tip es el siguiente: Utilizar el comando Get-Alias! Fácil, no?

Detallemos un ejemplo: Quiero saber el alias del comando Get-Alias (no tiene nombre mi capacidad creativa). Vamos a la consola de PowerShell y ejecutamos:

Get-Alias -Definition Get-Alias

Listo, obtenemos el nombre recortado del comando, que en este caso es **gal**

Espero no haberlos mareados con tanta información 🙂

Saludos,