---
title: 'Trabajar en PowerShell con fechas'
date: 2014-06-17T10:04:48+00:00
author: Victor Silva
layout: post
permalink: /powershell-fechas/
dsq_thread_id:
  - "4490571645"
categories:
  - PowerShell
tags:
  - PowerShell
  - Dates
  - Fechas
  - Cmdlets
  - Script
---
En algunos casos debemos trabajar con fechas sobre nuestros scripts. Vamos a ver algunas maneras de trabajar con las fechas, de darles formato y de crear un objeto en X días hacia adelante.

Lo primero que vamos a mencionar es el comando que realiza estas acciones: **Get-Date**.

Con este comando vamos a poder imprimir nuestra fecha como mas nos guste a nosotros. Pero para darle un formato adecuado a nuestra situación debemos utilizar el parámetro `-Format`.

El primer ejemplo es ver la fecha en formato largo, al estilo: _martes, 17 de junio de 2014_, el comando sería:

{% highlight posh %}
Get-Date -Format D
{% endhighlight %}

Si por el contrario, queremos ver un formato más reducido, por ejemplo _17/6/2014_, alcanza con escribir:

{% highlight posh %}
Get-Date -Formta d
{% endhighlight %}

Otro formato es el que nos muestra el día y el mes en letras: _17 de junio_, y debemos ejecutar:

{% highlight posh %}
Get-Date -Format M
{% endhighlight %}

Y que pasa si nosotros queremos ver la fecha a nuestra manera? Por ejemplo, solo el numero del día? Si contemplamos como fecha el día 17 de junio, nuestro resultado sería 17 y para ello, debemos ejecutar:

{% highlight posh %}
Get-Date -Formta dd
{% endhighlight %}

Otra forma de dar formato puede ser la siguiente, separando en cada línea los diferentes atributos:

{% highlight posh %}
$Date = Get-Date
"Day: " + $a.Day
"Month: " + $a.Month
"Year: " + $a.Year
"Hour: " + $a.Hour
"Minute: " + $a.Minute
"Second: " + $a.Second
{% endhighlight %}

Dando como resultado lo siguiente:

{% highlight plaintext %}
Day: 17
Month: 6
Year: 2014
Hour: 9
Minute: 32
Second: 44
{% endhighlight %}

Bien, todo perfecto, pero que sucede si nuestra intención es crear una objeto en el futuro, en días posteriores? Muy sencillo, debemos agregar el método **AddDays** desde el objeto *DataTime*, un ejemplo de ello sería:

{% highlight posh %}
(Get-Date).AddDays(10)
{% endhighlight %}

Generando un objeto que imprime en consola la fecha con 10 días hacia adelante.

Happy scripting!