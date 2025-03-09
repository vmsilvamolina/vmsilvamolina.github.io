---
title: 'PowerShell - Como borrar las carpetas vacías de una unidad?'
date: 2014-09-04T20:02:35+00:00
author: Victor Silva
layout: post
permalink: /powershell-como-borrar-las-carpetas-vacias-de-una-unidad/
dsq_thread_id:
  - "4488039470"
categories:
  - PowerShell
tags:
  - Borrar carpetas vacias
  - Cmdlets
  - PowerShell
---
Este es un pequeño bloque de código que alguna vez vi por la web:

{% highlight posh %}
$Unidad = Read-Host "Unidad de las carpteas"
$Objetos = Get-ChildItem $Drive -Recurse | Where-Object {$_.PSIsContainer -eq $True}
$Objetos | Where-Object {($_.GetFiles().Count -lt 1 -and $_.GetDirectories().Count -lt 1)} | Select-Object FullName | ForEach-Object {Remove-Item $_.fullname -Recurse}
{% endhighlight %}

El bloque de código anterior nos va a "preguntar" cuál es la unidad donde queremos revisar las carpetas vacías a eliminar.

Es práctico y lo podemos integrar en nuestros scripts para poder crear cosas más divertidas.

Happy scripting!