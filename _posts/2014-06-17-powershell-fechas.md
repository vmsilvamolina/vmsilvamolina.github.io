---
id: 409
title: 'PowerShell &#8211; Fechas'
date: 2014-06-17T10:04:48+00:00
author: Victor Silva
layout: single
guid: http://blog.victorsilva.com.uy/?p=409
permalink: /powershell-fechas/
dsq_thread_id:
  - "4490571645"
categories:
  - PowerShell
tags:
  - Cmdlets
  - Dates
  - Fechas
  - PowerShell
  - Script
---
En algunos casos debemos trabajar con fechas sobre nuestros scripts. Vamos a ver algunas maneras de trabajar con las fechas, de darles formato y de crear un objeto en X dias hacia adelante.

<!--more-->

Lo primero que vamos a mencionar es el comando que realiza estas acciones: **Get-Date**.

Con este comando vamos a poder imprimir nuestra fecha como mas nos guste a nosotros. Pero para darle un formato adecuado a nuestra situación debemos utilizar el parámetro **-Format**.

El primer ejemplo es ver la fecha en formato largo, al estilo: _martes, 17 de junio de 2014_, el comando sería:

<pre class="lang:ps decode:true">Get-Date -Format D</pre>

Si por el contrario, queremos ver un formato más reducido, por ejemplo _17/6/2014_, alcanza con escribir:

<pre class="lang:ps decode:true">Get-Date -Formta d</pre>

Otro formato es el que nos muestra el día y el mes en letras: _17 de junio_, y debemos ejecutar:

<pre class="lang:ps decode:true">Get-Date -Format M</pre>

Y que pasa si nosotros queremos ver la fecha a nuestra manera? Por ejemplo, solo el numero del día? Si contemplamos como fecha el día 17 de junio, nuestro resultado sería 17 y para ello, debemos ejecutar:

<pre class="lang:ps decode:true">Get-Date -Formta dd</pre>

Otra froma de dar formato puede ser la siguiente, separando en cada línea los diferentes atributos:

<pre class="lang:ps decode:true">$Date = Get-Date
"Day: " + $a.Day
"Month: " + $a.Month
"Year: " + $a.Year
"Hour: " + $a.Hour
"Minute: " + $a.Minute
"Second: " + $a.Second</pre>

Dando como resultado lo siguiente:

> Day: 17
  
> Month: 6
  
> Year: 2014
  
> Hour: 9
  
> Minute: 32
  
> Second: 44

Bien, todo perfecto, pero que sucede si nuestra intención es crear una objeto en el futuro, en días posteriores? Muy sencillo, debemos agregar el método AddDays desde el objeto DataTime, un ejemplo de ello sería:

<pre class="lang:ps decode:true">(Get-Date).AddDays(10)</pre>

Generando un objeto que nos imprime la fecha con 10 días hacia adelante.

Saludos,