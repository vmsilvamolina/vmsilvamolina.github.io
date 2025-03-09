---
title: Historial de comandos en una sesión
date: 2015-03-18T17:43:16+00:00
author: Victor Silva
layout: post
permalink: /historial-de-comandos-en-una-sesion/
dsq_thread_id:
  - "4485216458"
categories:
  - PowerShell
tags:
  - Clear-History
  - Get-History
  - Historial
  - PowerShell
  - sesión
---
En la consola de PowerShell en reiteradas oportunidades ejecuto muchos comandos y con diferentes configuraciones de parámetros y variables para obtener resultados, así como también a veces ejecuto bloques de código que quiero desarrollar y mejorar. Esto hace que cuando necesito buscar rápido un comando que ya ejecute o quiero simplemente dejar en orden los comandos ejecutados que yo sé que funcionaron se me complique bastante la búsqueda.

Para esto tenemos unos amigos que vamos a ir conociendo de a poco.

## Get-History

El primero de nuestra lista nos permite acceder a todo el historial de nuestra sesión activa en PowerShell (básicamente es acceder a los comandos que ejecute en la sesión activa). O sea, si cierro la ventana de la consola de PowerShell, pierdo el historial.

Un ejemplo claro es el siguiente:
 
Abro una consola de PowerShell, ejecuto **_Get-History_**. Como resultado no voy a obtener nada (ya que no hay historial en la sesión). Pero si vuelvo a ejecutar **_Get-History_**… Tengo un historial de un comando, el cual ya sabemos cuál es 😉

<img src="https://lh4.googleusercontent.com/--ph76iNadg0/VQnVI5SCpmI/AAAAAAAAG3o/ROMmtYkBWmA/w530-h206-no/PS_History_1.png" width="530" height="206" class="alignnone" />

Podemos uttilizar el comando para que solo nos muestre los comandos que contenga un texto especifico, por ejemplo la cadena "Get" ejecutando:

{% highlight posh %}
Get-History | Where-Object {$_.CommandLine -like "*Get*"}
{% endhighlight %}

De este comando también podemos observar que tiene el parámetro Count que nos permite mostrar el número especificado de los más recientes comandos listados en el historial.

## Clear-History

Creo que el nombre del comando nos da una gran pista… Elimina registros del historial de comandos ejecutados.

Voy a pasar a detallar algunos ejemplos para poder detallar mejor su funcionamiento.

{% highlight posh %}
Clear-History
{% endhighlight %}

Borra todas las entradas. Es lo mismo que si iniciamos la consola nuevamente, al ejecutar Get-History, no vamos a tener ninguna devolución.

Desarrollando más la función tenemos lo siguiente:

{% highlight posh %}
Clear-History -Id 4, 23
{% endhighlight %}

Simplemente va a borrar los registros de las entradas correspondientes a los números ingresados (comando listado con el número 4 y número23).

Mi último ejemplo es el siguiente:

{% highlight posh %}
Clear-History -Count 10 -Newest
{% endhighlight %}

Borra los 10 registros más nuevos del historial.

Espero que sea de utilidad tanto como a mí.

Happy scripting!