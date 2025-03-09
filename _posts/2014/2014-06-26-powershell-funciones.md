---
title: 'Funciones en PowerShell'
date: 2014-06-26T18:27:45+00:00
author: Victor Silva
layout: post
permalink: /powershell-funciones/
dsq_thread_id:
  - "4482550947"
categories:
  - PowerShell
tags:
  - PowerShell
  - Function
  - Funciones
---
En PowerShell podemos hacer uso de las llamadas funciones. _Definición:_ Una función es un bloque de código con un nombre definido, que permite "llamar" por este nombre a ese bloque de código, una o varias veces en nuestro script, para evitar la repetición de un conjunto de instrucciones continuamente.

Una de las razones por las que se usan mucho las funciones, es la capacidad de poder organizar la escritura del código. Permite la capacidad de llamar bloques de script varias veces, reduciendo la cantidad de código escrito para llevar a cabo la tarea final. Esto sin mencionar la mejora de la lectura del código, sea para entenderlo fácilmente o para poder encontrar un posible error.

La sintaxis para crear una función es la siguiente:

{% highlight posh %}
Function <nombre> { <bloque de código> }
{% endhighlight %}

Un ejemplo de función sería:

{% highlight posh %}
Function Fecha { Get-Date }
{% endhighlight %}

Si llamo a esta función el resultado es:

<img class="alignnone" src="https://lh4.googleusercontent.com/-gpHrE_UUIMw/U6N7qeXhvmI/AAAAAAAAFDk/elyrJnqK8ns/w380-h202-no/PS_function_example.png" alt="" width="380" height="202" />

Avanzando con el tema funciones, vamos a ver como podemos pasar argumentos a una función. Para ello vamos a declarar la siguiente función:

{% highlight posh %}
Function Sumar ($x, $y) {
  $sumar = $x + $y
  Write-Host “La respuesta es $sumar”
}
{% endhighlight %}

Que nos permitirá realizar la suma de 2 números e imprimir la respuesta dentro del mensaje definido.

Es decir que si definimos la función anterior y ejecutamos (escribimos y pulsamos enter):

{% highlight posh %}
Sumar 2 8
{% endhighlight %}

El resultado va a ser:

{% highlight plaintext %}
La respuesta es 10
{% endhighlight %}

Otra manera de definir parámetros en una función es con el siguiente método:

{% highlight posh %}
Function Sumar {
  param ($x, $y)

  $sumar = $x + $y
  Write-Host “La respuesta es $sumar”
}
{% endhighlight %}

De esta manera se expresan los parámetros dentro del bloque del script, pero siempre en primer lugar dentro de todo el código de la función.

Happy scripting!