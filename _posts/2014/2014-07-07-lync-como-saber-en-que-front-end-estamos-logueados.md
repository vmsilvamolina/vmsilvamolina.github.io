---
title: 'Saber en que Front End de Lync Server estamos logueados'
date: 2014-07-07T19:46:46+00:00
author: Victor Silva
layout: post
permalink: /lync-como-saber-en-que-front-end-estamos-logueados/
dsq_thread_id:
  - "4517246235"
categories:
  - PowerShell
  - Skype for Business Server
tags:
  - Cmdlets
  - Get-CsUserPoolInfo
  - Lync
  - PowerShell
  - RegistrarPool
---
Para los que trabajamos con Lync Server, a veces nos encontramos con la necesidad de saber datos en particular de los usuarios dentro de la implementación de Lync y de los servidores que pertenecen a nuestro entorno.

Un dato muy importante par realizar troubleshooting es saber en que servidor Front End se encuentra logueada un cuenta en particular. Para ello contamos con un comando que nos facilitará esta tarea.

El comando en cuestión es:

{% highlight posh %}
Get-CsUserPoolInfo -Identity <UserIdParameter> [-LocalStore <SwitchParameter>]
{% endhighlight %}

Muy bien, sabiendo la sintaxis del comando vamos a mostrar algunos ejemplos.

Conociendo al usuario en cuestión, cuya dirección **SIP** es **usuario@victorsilva.com.uy**, si queremos saber en quue servidor se esta logueando, basta con ejecutar la siguiente linea de código dentro de la Shell de administración de Lync:

{% highlight posh %}
Get-CsUserPoolInfo usuario@victorsilva.com.uy
{% endhighlight %}

Si en vez de querer conocer la información de un único usuario, queremos realizar esta consulta a todos los usuarios que se encuentran habilitados en nuestra implementación de Lync, debemos ejecutar el código que dejo a continuación:

{% highlight posh %}
Get-CsUser | Where-Object {$_.RegistrarPool -ne $Null} | Get-CsUserPoolInfo
{% endhighlight %}

El comando anterior, el comando primero llama al cmdlet **Get-CsUser** sin ningún parámetro para devolver una recopilación de todos los usuarios habilitados para Lync Server. Luego, se canaliza hacia el comando **Where-Object** que selecciona a los usuarios habilitados en Lync cuya propiedad _RegistralPool_ no es nula, es decir, están asignados a un pool de servidores. Después, la recopilación ya filtrada se canaliza al cmdlet **Get-CsUserPoolInfo**, que mostrará la información de grupo para cada usuario de la recopilación.

Happy scripting!