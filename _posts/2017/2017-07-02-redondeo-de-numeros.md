---
title: Redondeo de números y aritmética con PowerShell
date: 2017-07-02T20:39:09+00:00
author: Victor Silva
layout: post
permalink: /redondeo-de-numeros/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:11:"27b3d563efb";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:103:"https://medium.com/@vmsilvamolina/redondeo-de-n%C3%BAmeros-y-aritm%C3%A9tica-con-powershell-27b3d563efb";}'
dsq_thread_id:
  - "6064081752"
categories:
  - PowerShell
tags:
  - .Net
  - '[Math]'
  - Aritmética
  - Matemática
  - PowerShell
  - Round
---

Según [Wikipedia](https://es.wikipedia.org/wiki/Aritmetica):

> La aritmética es la rama de la matemática cuyo objeto de estudio son los números y las operaciones elementales hechas con ellos: adición, resta, multiplicación y división.

Así es que lo que vamos a comprobar hoy es la facilidad con la que podemos realizar operaciones desde PowerShell para intentar hacer un mundo mejor (o al menos, más automatizado) dentro de la matemática!

PowerShell ofrece de forma implícita la utilización de las operaciones elementales como se expresa en la definición de aritmética. Simplemente hay que ejecutar la operación a realizar como lo haríamos en la calculadora de Windows:

{% highlight posh %}
#sumar
8+5
#restar
12-8
#multiplicar
4*3
#dividir
150/5
{% endhighlight %}
    

Y los resultados serían los siguientes:

<img src="https://du0v0a-ch3302.files.1drv.com/y4mw_iO8Ry7ePyUa72zof4sD0s2tv43SacWe4EMJPHmbeUbXqOCQaYJBRSSNE-IwPIGCbaXxSHypbSGG5VczStl5mynfmDw95IkRwxTaR5ZOFMn4CObFGx_nSeDVLlnPls0UdAP_vS7l6CwtnE3ZhUb4lc-SQ7pjcTpED8uPtwPgOEwT3qfd-pzlG9FsLty5kwdE4p5d9HVSvlr1kEV94pnsw?width=827&#038;height=452&#038;cropmode=none" width="827" height="452" alt="Aritmetica con PowerShell" class="alignnone size-medium" />

Podemos armar algo más avanzado como se expresa a continuación:

{% highlight posh %}
# muiltiplicación
3 * (4 + 5)
#división
10 / (2 + 3)
{% endhighlight %}
    

<img src="https://du0u0a-ch3302.files.1drv.com/y4myCNz_bkVHF2vWgZZpFLSsn28x3vSxzYUcyUushVEXMbGRGfu_K_OGvcMhoOKalISwqZEyxuXOl_azojtYnS-BvPIcaY-c2Yg0xv0kicMauWk1ghgTHANIwx3XNlr4oLdv31r9sOP2fEdFRIqH8RLIm1BLDnqEz7necqq4SVqTx2SFAPstrILsuvbCo_mxgR2NSD_mh5z59J8shPQfFhm7g?width=827&#038;height=452&#038;cropmode=none" width="827" height="452" alt="Aritmética con PowerShell" class="alignnone size-medium" />

Logrando una hazaña inimaginable: Llegar a los límites del lenguaje! Bah, eso sería una realidad si no consideramos la facilidad que tiene PowerShell para poder expandir los operadores matemáticos que trae incorporados por defecto. Aunque parezca extraño, no se han añadido cálculos complejos en el lenguaje, pero podemos vivir tranquilos ya que siempre tenemos a mano .Net de forma casi nativa dentro de PowerShell.

## Matemática con PowerShell

Es por lo anterior que vamos a ver una _System class_ llamada **_[Math]_** que contiene unos 30 métodos para poder hacer matemática con ellos!

**[Math]** es una clase estática, lo que significa que no se puede crear un objeto [math]. Es una colección de métodos (fragmentos de código que podemos aprovechar en nuestros scripts) que han sido ubicados en nuestro camino para poder aprovecharlos.

En consecuencia a lo ya comentado, para poder observar que nos permite hacer esta clase (o al menos, que nos ofrece a nivel de métodos), debemos ejecutar la siguiente línea:

{% highlight posh %}
[math].GetMethods()
{% endhighlight %}

<img src="https://cp2pww-ch3302.files.1drv.com/y4mPmHrhYSCPm0DK7igk7iExLnfPQviiXi8SeiuGpMvkD95ZKbTspZghNrPZSsBMp_F_WjqoLM7xDVnZ6qhDc04--DBMCgxaLi8P14x5jqyDP0XSsf-i5sI-yLN2lJzumkte4Smxk-XG4GllCIOGUvtrrq6dXABib7K3Iwr5KZ4O_pkBwUTlwP2pzqB65piQXGFl45PkM0GI4wYE_I_QVkqUg?width=859&#038;height=632&#038;cropmode=none" width="859" height="632" alt="[Math].GetMethods()" class="alignnone size-medium" />

Y si el resultado es demasiada información para ubicarnos a leer cada línea sin perder medio día de nuestras vidas, lo mejor es filtrar por nombre:

{% highlight posh %}
[math].GetMethods() | select name -Unique
{% endhighlight %}

<img src="https://cp2nww-ch3302.files.1drv.com/y4m69RlFxZZ51p7XFBsm27vDxAoyLj3W24fZ1ldpr8UwE2P9w3iFOua5KLnvZHm7wxOTNhQJ6X9LYMspjeLXXVFWPK30rI20QSO8av2dnaDUlkhfgPHrPjioLw40_bCG8PWgPugVSMgrD0GiDTvzywEpLrcxpUBooMoy_aFLwXX65ucctO1iFZGzfPRAjgfo0er6Gk5mMcH07FRHzbGLZkPCw?width=859&#038;height=524&#038;cropmode=none" width="859" height="524" alt="[math].GetMethods() | select name -Unique" class="alignnone size-medium" />

Con el resultado de lo anterior podemos observar que existen algunas palabras que nos suenan familiar&#8230; Así que vamos a detallar el método que nos permite redondear nuestros números en la consola para poder sacarle fruto a nuestros scripts.

> Para poder invocar un método en la sentencia a ejecutar, es necesario usar el nombre de la clase y el nombre del método separados por dos puntos dobles (::).

## Redondeo de números con el método ::round()

Como se ha indicado en el título de la sección, el método **::round()** nos permite redondear números decimales definiendo la cantidad de cifras posteriores al punto que deseamos mantener:

{% highlight posh %}
[math]::round(123.4567)
{% endhighlight %}

El resultado de lo anterior es _123_ ya que en el ejemplo anterior no se ha utilizado el parámetro adicional que permite seleccionar cuantos decimales se desean mantener. Es decir si tengo el mismo número anterior (123.4567) y pretendo redondear con 2 decimales, debo ejecutar:

{% highlight posh %}
[math]::round(123.4567,2)
{% endhighlight %}

Obteniendo el número **_123&#46;46_** como resultado de lo ejecutado. Veamos algunos ejemplos adicionales para entender mejor su uso:

<img src="https://do2www-ch3302.files.1drv.com/y4mDAL83i73pEvHY66-R_rhO5ShJGVXjp32dO58SBLPn0n5CMUMHfES0ybGhB6TEHNjnERxIMHfIuSBL37CJGe6E-UvA97yf_tq6BbtlJAdknH8v3xoDf5N1-7E32VJOb4zX-c_dk75fwRpJLqEMOrQL0hvbftKoYQouuamSHSxSFm1McgOgTzAzkZ3aXAp3e1jIOqDFFdX_cS7cqAINpsvUw?width=859&#038;height=250&#038;cropmode=none" width="859" height="250" alt="Ejemplos de usos del método ::round()" class="alignnone size-medium" />

A modo de conclusión vimos que al intentar ejecutar el método con un valor para la cantidad de decilames negativo se produce un error.

Como dato adicional se recomienda usar el tipo de conversión dinámica que ofrece PowerShell al intentar redondear en naturales, de la siguiente manera:

{% highlight posh %}
#redondear sin los decimales
[int]123.456
#más recomendado que usar [math]::round(123.456)
{% endhighlight %}

## Método adicional

A su vez existe un parámetro adicional que puede ser utilizado dentro del método ::round() y es un tipo de redondeo llamado "
Away from zero"
. Consiste en agregar el tipo de enumeración [system.midpointrounding] como tercer parámetro de la siguiente forma:

{% highlight posh %}
[math]::round(123.456,2,[system.midpointrounding]::AwayFromZero)
{% endhighlight %}
    

Obteniendo como resultado: **123&#46;46**.

Existen otras maneras más practicas de declarar lo anterior (ya que recordar toda esa cadena de caracteres es un poco complejo):

{% highlight posh %}
[math]::round(123.456,2,[midpointrounding]::AwayFromZero)
[math]::round(123.456,2,"AwayFromZero")
[math]::round(123.456,2,1)
{% endhighlight %}

<img src="https://do2vww-ch3302.files.1drv.com/y4mM9nDc-7OWVhqENoIEhMuERuoXe_OHAjKAT-sqZC2ydbzD0DrXZ3sAeJUZAyB5P772j-yvINRMK7h1k3ebH4DQgNV5NqqAbZ2jtXi2AIuZBa08Ugy6JEM2pfB5sP3kMrDcO3Vc3AivSCpj-mP3nDZDjldUb0-KVT9cWVkw1UTvSWpIGA-fTZH9uriKF4aCO7z8dyNAWqKcW6B3FlpnSv8TA?width=859&#038;height=222&#038;cropmode=none" width="859" height="222" alt="Ejemplos de uso del tipo de redondeo Away from zero" class="alignnone size-medium" />

En el ejemplo se muestra con amarillo que siempre se usó el mismo número decimal y que los resultados cambian dependiendo de los parámetros que se utilizan: con Rojo se resalta el resultado de redondear como veníamos trabajando y con Verde se resaltan los resultados de utilizar el tipo de redondeo "
Away from zero"
.

Para obtener un mayor detalle de los métodos que ofrece la clase _Math_, adjunto el enlace de la documentación oficial que hace referencia a los diferentes métodos existentes en mayor profundidad:

[Math Methods](https://msdn.microsoft.com/en-us/library/system.math_methods%28v=vs.110%29.aspx).

Espero que sea de ayuda.

Happy scripting!