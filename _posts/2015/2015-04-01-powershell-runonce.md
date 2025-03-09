---
title: 'PowerShell - RunOnce'
date: 2015-04-01T16:20:37+00:00
author: Victor Silva
layout: post
permalink: /powershell-runonce/
dsq_thread_id:
  - "4524196751"
categories:
  - PowerShell
tags:
  - post-inicio
  - PowerShell
  - Registry
  - RunOnce
  - Script
---
Que es **_RunOnce_**? Es una manera de ejecutar comandos gracias al registro de Windows. Con esta clave de registro podemos declarar acciones post-reinicio, para poder completar nuestros procedimientos y/o instalaciones de manera más automática.

Esta clave se encuentra en dos rutas particulares:

  * HKEY\_LOCAL\_MACHINE\Software\Microsoft\Windows\CurrentVersion\RunOnce
  * HKEY\_CURRENT\_USER\Software\Microsoft\Windows\CurrentVersion\RunOnce

Por lo que podemos definir si queremos que el código se ejecute luego de reiniciar la maquina utilizando la ruta correspondiente a **HKEY\_LOCAL\_MACHINE**, sin importar que usuario inicia sesión. O tenemos la ruta de **HKEY\_CURRENT\_USER** que permite ejecutar las acciones necesarias sólo con el usuario que crea la clave en el momento de estar iniciada la sesión.

Un ejemplo de uso, podría ser la necesidad de ejecutar un script ya guardado en la ruta **_C:\Scripts\Parte2.ps1_** para poder completar un procedimiento en particular. Para ello vamos a agregar una línea de código en nuestro script "Parte1.ps1":

{% highlight posh %}
New-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce -Name "Parte2" -Value "powershell.exe -ExecutionPolicy Unrestricted -Command `"C:\Scripts\Parte2.ps1`""
{% endhighlight %}

Les comparto un enlace que habla sobre esta clave en particular: [link](https://msdn.microsoft.com/en-us/library/windows/desktop/aa376977%28v=vs.85%29.aspx).

Happy scripting!