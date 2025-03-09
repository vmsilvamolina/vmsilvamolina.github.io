---
title: 'PowerShell - Añadir y remover items de un Array'
date: 2014-07-19T15:21:05+00:00
author: Victor Silva
layout: post
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

{% highlight posh %}
$Frutas = "Manzana","Pera","Banana","Naranja"
{% endhighlight %}

Y luego ejecutamos:

{% highlight posh %}
$Frutas.GetType()
{% endhighlight %}

<img class="alignnone" src="https://lh4.googleusercontent.com/-Pixpgm8QK68/U95MRodMPQI/AAAAAAAAFQo/4NDfpPIRyXo/w700-h267-no/PS_Array_1.png" alt="" width="700" height="267" />

Si intentamos añadir un elemento o borrarlo nos aparece un mensaje de error:

{% highlight posh %}
$Frutas.Add("Kiwi")
$Frutas.Remove("Manzana")
$Frutas.IsFixedSize
{% endhighlight %}

<img class="alignnone" src="https://lh6.googleusercontent.com/-U4AY7zL22L4/VAUMk1NVZiI/AAAAAAAAFms/fo9qEqohhlc/w877-h351-no/PS_Arrays_2.png" alt="" width="877" height="351" />

La página de la MSDN explica la propiedad _IsFixedSize_, propiedad que aparece cuando se crea la matriz de la manera en que la creamos en el ejemplo.

Una manera de poder lidiar con este problema es utilizar **_System.Collections.ArrayList_** de la siguiente manera:

<img class="alignnone" src="https://lh5.googleusercontent.com/-yull0nPME3E/VAUSLOYxDLI/AAAAAAAAFnA/tYgeJHZ-NpY/w877-h197-no/PS_Arrays_3.png" alt="" width="877" height="197" />

Y de esta manera vamos a poder modificar los elementos del _Array:_

{% highlight posh %}
$Matriz.Add("Kiwi")
$Matriz
{% endhighlight %}

Otra manera de agregar elementos a un nuevo array sumando los de otro ya definido es:

{% highlight posh %}
$NuevoArray = $Frutas += "Melón"
{% endhighlight %}

Y si en vez de adicionar un elemento o elementos en un nuevo array, queremos eliminar la manera correcta sería ejecutando:

{% highlight posh %}
$MenosFrutas = $Frutas -ne "Manzana"
{% endhighlight %}

Y por último podemos utilizar la siguiente sintaxis, que realiza lo mismo pero de otra manera:

{% highlight posh %}
$FrutasNuevas = {$Frutas}.Invoke()
{% endhighlight %}

Happy scripting!