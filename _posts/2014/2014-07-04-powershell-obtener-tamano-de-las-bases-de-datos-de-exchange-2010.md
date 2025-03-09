---
title: 'PowerShell - Obtener tamaño de las bases de datos de Exchange 2010'
date: 2014-07-04T11:15:50+00:00
author: Victor Silva
layout: post
permalink: /powershell-obtener-tamano-de-las-bases-de-datos-de-exchange-2010/
dsq_thread_id:
  - "4478929053"
categories:
  - Exchange
  - PowerShell
tags:
  - PowerShell
  - Exchange
  - Database
  - Cmdlets
---
Un simple tip de como obtener desde PowerShell el o los tamaños de las bases de datos de nuestro Exchange Server 2010.

Normalmente estamos preocupados por el tamaño de nuestras bases de datos y mas si son de un servicio tan critico como el correo, debemos saber si estarán llegando al límite, si tengo que dar mas espacio libre, si tengo que hacer una defragmentación. Os propongo este [cmdlet](http://technet.microsoft.com/es-es/library/aa996589.aspx) que en una sola línea nos da la información del tamaño de todas nuestras bases de datos

Simplemente desde la Exchange Management Shell, debemos ejecutar la siguiente linea:

{% highlight posh %}
Get-MailboxDatabase -Status | fl name, databasesize
{% endhighlight %}

Devolviendo lo siguiente por ejemplo:

<img class="alignnone" src="https://lh3.googleusercontent.com/-1Byp3ghP7qU/VAdq3OBte8I/AAAAAAAAFoQ/ZeVhXLRH-sw/w612-h141-no/Exchange_Shell_DBstatus.png" alt="" width="612" height="141" />

Y con eso sería todo.

Happy scripting!