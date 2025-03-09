---
title: 'PowerShell - Eliminar último caracter de una cadena (String)'
date: 2014-07-24T19:40:57+00:00
author: Victor Silva
layout: post
permalink: /powershell-eliminar-ultimo-caracter-de-una-cadena-string/
dsq_thread_id:
  - "4492344694"
categories:
  - PowerShell
tags:
  - Cmdlets
  - Eliminar caracter
  - PowerShell
---
Esto es bien cortito... No tengo ganas de escribir, pero si de compartir un "tip" importante!

Para los que trabajan manipulando texto en los scripts, este truco es bastante útil, así como los que por diferentes motivos necesitan modificar strings al trabajar por medio de scripts.

El objetivo es mostrar con una procedimiento bien simple como eliminar el último caracter de una cadena (string). Vamos a mostrar la manera desde un ejemplo bien básico:

{% highlight posh %}
#Defino una cadena de caracteres
$Variable = "Texto que quiero modificar"
#Aplico la "magia"
$Varible = $Variable -replace ".$"
#Llamo a la variable
$Variable
{% endhighlight %}

<img class="alignnone" src="https://lh5.googleusercontent.com/-gJNkMoyRWqM/VAY3AgeVtaI/AAAAAAAAFnc/gVO1mEWWL1o/w877-h211-no/PS_EliminarCaracter.png" alt="" width="877" height="211" />

Happy scripting!