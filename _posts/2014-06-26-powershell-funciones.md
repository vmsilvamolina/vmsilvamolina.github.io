---
id: 420
title: 'PowerShell &#8211; Funciones'
date: 2014-06-26T18:27:45+00:00
author: Victor Silva
layout: simple
guid: http://blog.victorsilva.com.uy/?p=420
permalink: /powershell-funciones/
dsq_thread_id:
  - "4482550947"
categories:
  - PowerShell
tags:
  - Funciones
  - PowerShell
---
En PowerShell podemos hacer uso de las llamadas funciones. _Definición:_ Una función es un bloque de código con un nombre definido, que permite &#8220;llamar&#8221; por este nombre a ese bloque de código, una o varias veces en nuestro script, para evitar la repetición de un conjunto de instrucciones continuamente.

<!--more-->

Una de las razones por las que se usan mucho las funciones, es la capacidad de poder organizar la escritura del código. Permite la capacidad de llamar bloques de script varias veces, reduciendo la cantidad de codigo escrito para llevar a cabo la tarea final. Esto sin mencionar la mejora de la lectura del código, sea para entenderlo facilmente o para poder encontrar un posible eror.

La sintaxis para crear una función es la siguiente:

<pre class="lang:ps decode:true">Function &lt;nombre&gt; { &lt;bloque de código&gt; }</pre>

Un ejemplo de función sería:

<pre class="lang:ps decode:true">Function Fecha { Get-Date }</pre>

Si llamo a esta función el resultado es:

<img class="alignnone" src="https://lh4.googleusercontent.com/-gpHrE_UUIMw/U6N7qeXhvmI/AAAAAAAAFDk/elyrJnqK8ns/w380-h202-no/PS_function_example.png" alt="" width="380" height="202" />

&nbsp;

Avanzando con el tema funciones, vamos a ver como podemos pasar argumentos a una función. Para ello vamos a declarar la siguiente función:

<pre class="lang:ps decode:true">Function Sumar ($x, $y)
{
$sumar = $x + $y
Write-Host “La respuesta es $sumar”
}</pre>

Que nos permitirá realizar la suma de 2 numeros e imprimir la respuesta dentro del mensaje definido.

Es decir que si definimos la función anterior y ejecutamos (escribimos y pulsamos enter):

<pre class="lang:ps decode:true">Sumar 2 8</pre>

El resultado va a ser:

> La respuesta es 10

Otra manera de definir parametros en una función es con el siguiente metodo:

<pre class="lang:ps decode:true ">Function Sumar
{
param ($x, $y)

$sumar = $x + $y
Write-Host “La respuesta es $sumar”
}</pre>

De esta manera se expresan los parametros dentro del bloque del script, pero siempre en primer lugar dentro de todo el codigo de la función.

&nbsp;

Saludos,

&nbsp;