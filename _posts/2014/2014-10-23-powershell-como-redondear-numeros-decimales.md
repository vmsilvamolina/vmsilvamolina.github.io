---
title: 'PowerShell - Cómo redondear números decimales'
date: 2014-10-23T19:09:16+00:00
author: Victor Silva
layout: post
permalink: /powershell-como-redondear-numeros-decimales/
dsq_thread_id:
  - "4472639286"
categories:
  - PowerShell
tags:
  - PowerShell
  - Redondear
  - Round
---
Todos, absolutamente todos los que trabajan con datos, en algún momento tuvimos la necesidad de redondear esos números con montones de decimales.

Es por ello, que en esta oportunidad voy a compartir un pequeño tip, una ayuda para hacer más fácil esta tarea.

Vamos a suponer que tenemos una operación simple que nos genera un número feo, por ejemplo: **44/7**.

El resultado de esta operación es: **_63,428571&#8230;_**

Para poder redondear este numero tenemos que anteponer lo siguiente:

{% highlight posh %}
[math]::Round(44/7)
{% endhighlight %}

Obteniendo como resultado: **_6_**

Happy scripting!