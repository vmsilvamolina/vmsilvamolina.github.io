---
id: 465
title: 'Lync &#8211; Como saber las versiones de Lync Server instaladas?'
date: 2014-07-10T10:39:39+00:00
author: Victor Silva
layout: post
guid: http://blog.victorsilva.com.uy/?p=465
permalink: /lync-como-saber-las-versiones-de-lync-server-instaladas/
dsq_thread_id:
  - "4728813474"
categories:
  - PowerShell
  - Skype for Business Server
tags:
  - Cmdlets
  - Lync Server
  - PowerShell
  - versiones
format: aside
---
Un pequeño comando que nos permitirá conocer las versiones de los diferentes roles de nuestra implementación de Lync Server.

Muy útil, cuando nos encontramos con la necesidad de actualizar o de ver los parches disponibles de nuestra implementación.

Simplemente desde una Shell de adminitración de Lync, debemos ejecutar la siguiente línea de código:

<pre class="lang:ps decode:true ">Get-WmiObject -Query 'select * from win32_product' | where {$_.name -like "Microsoft Lync Server*"} | foreach {$_}</pre>

Saludos,