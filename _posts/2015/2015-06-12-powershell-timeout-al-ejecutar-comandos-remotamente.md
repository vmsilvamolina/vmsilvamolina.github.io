---
title: 'Timeout al ejecutar comandos remotamente'
date: 2015-06-12T23:49:02+00:00
author: Victor Silva
layout: post
permalink: /powershell-timeout-al-ejecutar-comandos-remotamente/
dsq_thread_id:
  - "4601820923"
categories:
  - PowerShell
tags:
  - PowerShell
  - Registro Remoto
  - Servicio
  - Timeout
---
Trabajando con scripts que se ejecutan en servidores remotos, en una oportunidad encontré que al intentar ejecutar un comando, generaba un error de timeout al ejecutar comandos remotamente.

Empecé con aislar el servidor e intentar ejecutar comandos para ver el comportamiento. Lo primero que intente es:

{% highlight posh %}
Get-Process -ComputerName Servidor01
{% endhighlight %}

Y nada, error.

## Solución

Revisando los servicios del servidor en cuestión (Servidor01) encontré que el servicio **_Registro Remoto_** estaba detenido.

Inicié el servicio con la cuenta **_NT AUTHORITY\LocalService_** sin password, intenté nuevamente y&#8230; Perfecto!

<img src="https://lh6.googleusercontent.com/-BAfqGYvnnLE/VYYbCezbyaI/AAAAAAAAHAs/mqpIhG8FpLo/w896-h292-no/PS_Timeout_01.png" width="896" height="292" class="alignnone" />

Problema resuelto!

<img src="https://lh4.googleusercontent.com/-ZzBDNqG4rks/VYYbCXkdHrI/AAAAAAAAHAw/BaieWi9pi4k/w638-h294-no/PS_Timeout_02.png" width="638" height="294" class="alignnone" />

Enlace para que puedan seguir aprendiendo sobre scripting remoto: [enlace](https://technet.microsoft.com/es-es/library/dd819505.aspx)

Happy scripting!