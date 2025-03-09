---
title: 'PowerShell - Verificar KB instalado'
date: 2015-01-12T10:22:05+00:00
author: Victor Silva
layout: post
permalink: /powershell-verificar-kb-instalado/
dsq_thread_id:
  - "4488037003"
categories:
  - PowerShell
tags:
  - Get-HotFix
  - HotFix
  - KB
  - PowerShell
---
Para verificar si tenemos un KB (o HotFix) instalado en nuestro equipo rápidamente, tenemos un comando que realiza esta función a la perfección.

El comando en cuestión es [Get-HotFix](https://technet.microsoft.com/en-us/library/hh849836.aspx) y voy a pasar a detallar un par de ejemplos de uso:

Si necesitamos saber el total de hotfixs instalados en nuestro equipo, simplemente escribimos lo siguiente:

{% highlight posh %}
Get-Hotfix
{% endhighlight %}


Si en cambio, sabemos que HotFix estamos buscando, el comando cambia agregando lo siguiente:

{% highlight posh %}
Get-HotFix -Id 2919355
{% endhighlight %}

Donde el número es el ID del KB.

Otra variante es chequear en varios equipos (Server01, Server02) que Hotfix,comenzando con la palabra "Security" en la descripción se encuentran instalados, detallando las credenciales de acceso:

{% highlight posh %}
Get-HotFix -Description Security* -ComputerName Server01, Server02 -Cred Server01\Administrator
{% endhighlight %}

Happy scripting!