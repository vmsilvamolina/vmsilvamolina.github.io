---
id: 510
title: 'PowerShell: Obtener el directorio donde nos encontramos'
date: 2014-09-17T19:54:47+00:00
author: Victor Silva
layout: single
guid: http://blog.victorsilva.com.uy/?p=510
permalink: /powershell-obtener-el-directorio-donde-nos-encontramos/
dsq_thread_id:
  - "4471578571"
categories:
  - PowerShell
tags:
  - Cmdlets
  - Convert-Path
  - PowerShell
  - Tip
format: aside
---
Es muy sencillo y quería compartirlo con ustedes.

Utilizamos el comando Convert-Path y de parametro simplemente tipeamos un punto (.).

<pre class="lang:default decode:true ">Convert-Path .</pre>

Con eso nos basta para poder obtener la ruta donde nos encontramos trabajando.

Para los linuxeros esto sería un pwd, no?

Dejo un enlace para mayo referencia del comando [Convert-Path](http://technet.microsoft.com/en-us/library/hh849856.aspxhttp:// "TechNet: Convert-Path")

&nbsp;

Saludos,