---
title: El parámetro Passthru en PowerShell
date: 2018-03-10T23:51:00+00:00
author: Victor Silva
layout: post
permalink: /passthru-en-powershell/
excerpt: "El parámetro 'passthru' es utilizado con frecuencia, pero sin conocer realmente que es lo que permite realizar, o al menos que es lo que hace de manera simple. Básicamente permite agregar una salida a cmdlets que no tienen esta función por defecto, es decir que agrega una funcionalidad o extiende el uso de ciertos cmdlets."
categories:
  - PowerShell
tags:
  - Cmdlet
  - Parámetro Passthru
  - Pasthru
  - PowerShell
---
El parámetro **_passthru_** es utilizado con frecuencia, pero sin conocer realmente que es lo que permite realizar, o al menos que es lo que hace de manera simple. Básicamente permite agregar una salida a cmdlets que no tienen esta función por defecto, es decir que agrega una funcionalidad o extiende el uso de ciertos cmdlets.

Su principal uso o por lo que la mayoría de las personas utilizan el parámetro **_passthru_** es la posibilidad de verificar que es lo que hace un cmdlet en particular o que se pretende lograr como resultado.

## Usando el parámetro passthru

Todos conocemos varios cmdlets que devuelven "
cosas"
 por defecto: los que empiezan con Get, New, Set de los módulos que manejamos a diario de seguro nos arrojan información a la consola de manera predeterminada. Pero como comentamos anteriormente, en otros no ocurren acciones de salida. Cumple lo anterior el cmdlet **_Copy-Item_**, simplemente copia el o los objetos desde el origen al destino sin acusar nada luego de finalizado, veamos un pequeño ejemplo:

{% highlight posh %}
Copy-Item -Path C:\Temp\File.txt -Destination .\Desktop
{% endhighlight %}

Otro ejemplo que clarifica esta situación se presenta al utilizar el cmdlet Get-Process:

{% highlight posh %}
Get-Process | Out-File C:\reports\Process.txt
{% endhighlight %}

Estos son dos ejemplos típicos de comandos que no tiene salida y que en el uso diario capaz que no es necesario tener una salida. ¿Y que sucede si en cierta situación requerimos tener un resultado? Para poder resolver el requerimiento es necesario recurrir al parámetro passthru, de la siguiente manera:

{% highlight posh %}
Copy-Item -Path C:\Temp\File.txt -Destination .\Desktop -Passthru
{% endhighlight %}

Obteniendo el siguiente resultado:

<img src="https://oy9bda.ch.files.1drv.com/y4mdh6j1Zs8YimJvK0OqZ3KvjEvZUynrWWtYDS2vZ4jS8m2XMBQ4_MBBbY9bGqW87K_qahWuQ-1bM4rSD7U0QyRgqvlt0QRfs_aoJKzFxaXseEG8iZ9ZzIdMypKcBKYSGoXo78e5vwlRbHvV_84tMyAOXQ0C-qbj8R7chzWYVGy5VO2zjzlMeqV--E9fEOb7GY_v--dMP07Ara0Hvj_AWPtCw?width=859&height=205&cropmode=none" width="859" height="205" alt="Copy-Item con el parámetro Passthru" class="alignnone size-medium" />

### Encontrar comandos con el parámetro passthru

Para obtener una lista con todos los cmdlets que cuentan con el parámetro _passthru_ disponibles para usar debemos ejecutar algo como la siguiente línea:

{% highlight posh %}
Get-Command -PipelineVariable commands | `
where { $_.ParameterSets.Parameters.Name -eq "PassThru" } | ForEach-Object {$commands}
{% endhighlight %}

Tomando como referencia los cmdlets disponibles según los módulos actuales en la consola.

Happy scripting!