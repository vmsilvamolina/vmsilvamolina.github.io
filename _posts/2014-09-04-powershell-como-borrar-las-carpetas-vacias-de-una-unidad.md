---
id: 512
title: 'PowerShell: Como borrar las carpetas vacías de una unidad?'
date: 2014-09-04T20:02:35+00:00
author: Victor Silva
layout: simple
guid: http://blog.victorsilva.com.uy/?p=512
permalink: /powershell-como-borrar-las-carpetas-vacias-de-una-unidad/
dsq_thread_id:
  - "4488039470"
categories:
  - PowerShell
tags:
  - Borrar carpetas vacias
  - Cmdlets
  - PowerShell
format: aside
---
Este es un pequeño bloque de código que alguna vez vi por la web:

<pre class="lang:default decode:true">$Unidad = Read-Host "Unidad de las carpteas"
$Objetos = Get-ChildItem $Drive -Recurse | Where-Object {$_.PSIsContainer -eq $True}
$Objetos | Where-Object {($_.GetFiles().Count -lt 1 -and $_.GetDirectories().Count -lt 1)} | Select-Object FullName | ForEach-Object {Remove-Item $_.fullname -Recurse}</pre>

El bloque de codigo anterior nos va a &#8220;preguntar&#8221; cuál es la unidad donde queremos revisar las carpetas vacías a eliminar.

Es práctico y lo podemos integrar en nuestros scripts para poder crear cosas más divertidas.

&nbsp;

Saludos,