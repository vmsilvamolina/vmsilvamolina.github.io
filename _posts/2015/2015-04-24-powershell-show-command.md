---
title: 'PowerShell - Show-Command'
date: 2015-04-24T10:29:46+00:00
author: Victor Silva
layout: post
permalink: /powershell-show-command/
dsq_thread_id:
  - "4486990669"
categories:
  - PowerShell
tags:
  - Cmdlet
  - PowerShell
  - Show-Command
---
El comando del que voy a hablar, es Show-Command. Si bien no es un comando que haga magias raras, es muy útil para aprender y/o enseñar sobre otros comandos. Por qué? Que tiene de mistico? Dicen que una imagen vale mas que mil palabras…

Abrimos una consola de PowerShell y ejecutamos **_Show-Command_**. Nos debe aparecer algo como esto:

<img src="https://lh4.googleusercontent.com/-89OManPA87E/VUYXKDElTCI/AAAAAAAAG7c/3m0-B93aXAw/w365-h576-no/PS_Show_01.png" width="365" height="576" class="alignnone" />

El comando nos muestra una lista (gráfica) de todos los comandos de todos los módulos disponibles. Puede que eso no sea muy mágico, pero si ejecutamos el mismo comando con otro comando como parametro, por ejemplo:

{% highlight posh %}
Get-Command Rename-Computer
{% endhighlight %}

Nos abre una interfaz gráfica con un formulario que contiene los parametros del comando!!! Eso si es muy bueno.

O sea, que podemos aprender de los parametros de comandos particulares, o ver las diferentes opciones que tiene cada comando en particular.

Al ser un formulario, vamos a tener marcados con un asterisco en rojo los que son mandatorios (sí o sí tenemos que completar).

Por mas información sobre el comando, les dejo el enlace a la TechNet: [Show-Command](https://technet.microsoft.com/en-us/library/hh849915.aspx)

Happy scripting!