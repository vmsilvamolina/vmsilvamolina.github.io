---
id: 482
title: 'PowerShell &#8211; Eliminar último caracter de una cadena (String)'
date: 2014-07-24T19:40:57+00:00
author: Victor Silva
layout: post
guid: http://blog.victorsilva.com.uy/?p=482
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
Esto es bien cortito&#8230; No tengo ganas de escribir, pero si de compartir un &#8220;tip&#8221; importante!

Para los que trabajan manipulando texto en los scripts, este truco es bastante útil.

Vamos a mostrar la manera desde eun ejemplo bien básico:

<pre class="lang:default decode:true">#Defino una cadena de caracteres
$Variable = "Texto que quiero modificar"
#Aplico la "magia"
$Varible = $Variable -replace ".$"
#Llamo a la variable
$Variable
</pre>

<img class="alignnone" src="https://lh5.googleusercontent.com/-gJNkMoyRWqM/VAY3AgeVtaI/AAAAAAAAFnc/gVO1mEWWL1o/w877-h211-no/PS_EliminarCaracter.png" alt="" width="877" height="211" />

Saludos,