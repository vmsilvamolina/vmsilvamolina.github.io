---
id: 459
title: 'PowerShell &#8211; Añadir y remover items de un &#8220;Array&#8221;'
date: 2014-07-19T15:21:05+00:00
author: Victor Silva
layout: post
guid: http://blog.victorsilva.com.uy/?p=459
permalink: /powershell-anadir-y-remover-items-de-un-array/
dsq_thread_id:
  - "4491949024"
categories:
  - PowerShell
tags:
  - Array
  - Cmdlets
  - PowerShell
  - Syntax
---
Este es un tema bastante confuso, por lo que vamos a ver algunos consejos a la hora de manipular arrays en PowerShell.

Los primero que vamos a hacer es crear un array y ver que tipo de elemento es:

<pre class="lang:ps decode:true">$Frutas = "Manzana","Pera","Banana","Naranja"</pre>

Y luego ejecutamos:

<pre class="lang:ps decode:true">$Frutas.GetType()</pre>

<img class="alignnone" src="https://lh4.googleusercontent.com/-Pixpgm8QK68/U95MRodMPQI/AAAAAAAAFQo/4NDfpPIRyXo/w700-h267-no/PS_Array_1.png" alt="" width="700" height="267" />

Si intentamos añadir un elemento o borrarlo nos aparece un mensaje de error:

<pre class="lang:ps decode:true ">$Frutas.Add("Kiwi")

$Frutas.Remove("Manzana")

$Frutas.IsFixedSize</pre>

<img class="alignnone" src="https://lh6.googleusercontent.com/-U4AY7zL22L4/VAUMk1NVZiI/AAAAAAAAFms/fo9qEqohhlc/w877-h351-no/PS_Arrays_2.png" alt="" width="877" height="351" />

La página de la MSDN explica la propiedad _IsFixedSize_, propiedad que aparece cuando se crea la matriz de la manera en que la creamos en el ejemplo.

Una manera de poder lidiar con este problema es utilizar **_System.Collections.ArrayList_** de la siguiente manera:

<img class="alignnone" src="https://lh5.googleusercontent.com/-yull0nPME3E/VAUSLOYxDLI/AAAAAAAAFnA/tYgeJHZ-NpY/w877-h197-no/PS_Arrays_3.png" alt="" width="877" height="197" />

Y de esta manera vamos a poder modificar los elementos del _Array:_

<pre class="lang:ps decode:true">$Matriz.Add("Kiwi")

$Matriz</pre>

Otra manera de agregar elementos a un nuevo array sumando los de otro ya definido es:

<pre class="lang:ps decode:true">$NuevoArray = $Frutas += "Melón"
</pre>

Y si en vez de adicionar un elemento o elementos en un nuevo array, queremos eliminar la manera correcta sería ejecutando:

<pre class="lang:ps decode:true">$MenosFrutas = $Frutas -ne "Manzana"</pre>

Y por último podemos utilizar la siguiente sintaxis, que realiza lo mismo pero de otra manera:

<pre class="lang:ps decode:true">$FrutasNuevas = {$Frutas}.Invoke()</pre>

Saludos,