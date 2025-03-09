---
title: 'PowerShell - Obtener parte de una cadena (string)'
date: 2014-08-07T20:28:45+00:00
author: Victor Silva
layout: post
permalink: /powershell-obtener-parte-de-una-cadena-string/
dsq_thread_id:
  - "4471578500"
categories:
  - PowerShell
tags:
  - Cmdlets
  - PowerShell
  - Split()
  - String
---
En algunas oportunidades nos encontramos con situaciones en las que debemos de resolver. Una de estas situaciones puede ser trabajar con cadenas de caracteres y tener que utilizar solo una parte de ellas, como puede ser por ejemplo un alias de un mail, una sección de un directorio donde se encuentra un archivo, una parte de una fecha, en fin, ejemplos abundan.

Para poder superar esta situación puedo compartir una pequeña enseñanza: El método de PowerShell _Split_.

Vamos a ver algunos ejemplos:

{% highlight posh %}
$Cadena = "Hola soy una cadena"
$Cadena.Split()
{% endhighlight %}

En el ejemplo anterior vemos como se corta la cadena tomando como referencia el espacio entre caracteres. Que sucede si por ejemplo tenemos una cadena en la que nuestro "separador" son dos puntos (:)

Debemos de definir el método split de la siguiente manera:

{% highlight posh %}
$Cadena = "Unidad:Carpeta:Archivos:"
$Cadena.Split(":")
{% endhighlight %}

<img class="alignnone" src="https://lh3.googleusercontent.com/-2DrwCcfYDFY/VCgkEKgG7fI/AAAAAAAAF4Q/5-DtZpg6UjA/w492-h200-no/PS_Split.png" alt="" width="492" height="200" />

Y así definiendo cada separador que no interese.

Pero que sucede si aparte de cortar las cadenas de caracteres, necesitamos tomar una parte de esos string? simplemente los invocamos de la siguiente manera:

Vamos a considerar el último ejempl y que a su vez, necesitamos obtener solamente la palabra "Carpeta", simplemente debemos modificar la última línea agregando:

<img class="alignnone" src="https://lh6.googleusercontent.com/-D9nGFjQPagc/VCgkEMZ1qCI/AAAAAAAAF4M/MU7oDoLhc58/w492-h200-no/PS_Split_2.png" alt="" width="492" height="200" />

{% highlight posh %}
$Cadena = "Unidad:Carpeta:Archivos:"
$Cadena.Split(":")[1]
{% endhighlight %}

Y listo!

Happy scripting!