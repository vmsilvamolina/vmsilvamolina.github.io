---
title: YouTube desde PowerShell
date: 2018-02-24T12:30:46
author: Victor Silva
layout: post
permalink: /youtube-desde-powershell/
excerpt: "Hoy en es.stackoverflow.com, dentro del tag PowerShell encontré una consulta sobre la posibilidad de realizar búsquedas en YouTube desde la consola y allí poder comenzar a mirar videos relacionados a lo que interesaba buscar, simplemente ejecutando una única función desde la consola."
categories:
  - PowerShell
tags:
  - PowerShell
  - Youtube
  - InternetExplorer.Application
---

<div><b>Actualizado:</b> 11 de Abril de 2018</div>{: .notice}

Hoy en [Stackoverflow en español](https://es.stackoverflow.com), dentro del tag *PowerShell* encontré una consulta sobre la posibilidad de realizar búsquedas en YouTube desde la consola y allí poder comenzar a mirar videos relacionados a lo que interesaba buscar, simplemente ejecutando una única función desde la consola.

De lo anterior surgió este post para compartirlo con más detalles y cómo llegué a la función final (que por cierto va a estar al final del post).

Lo primero de lo que voy a hablar es sobre como trabajar directamente con Internet Explorer, u otro navegador (para el post se utilizó IE). Para ello tenemos un cmdlet llamado [New-Object](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/new-object?view=powershell-6), que permite generar objectos como indica el nombre. Puntualmente utilizamos esta función para crear una instancia del objecto COM que representa la aplicación Internet Explorer.
Adicional a esto, es posible utilizar el método **Navigate2** para definir la URL a la que queremos navegar y definimos el valor de la propiedad **Visible** en *$True* para que la aplicación sea visible:

{% highlight posh %}
$ie = New-Object -ComObject "InternetExplorer.Application"
  $ie.navigate2("https://www.youtube.com/?hl=es&gl=ES")
  $ie.visible = $True
{% endhighlight %}


<img src="https://q169pq.ch.files.1drv.com/y4mKMrKNqniNRBAYb-C2FxR28V5rwPpltdx9E6y2q7XqKCT5WRvuS9Y-b9WDnPafkFi4PURzvGJpBVs3fGCqKCVuRPEH-_t7VrclQ7J6rKbYcXiBJ0Y1IQ1iIkkHVlKMEEopjrUrjboWlEFkUmEgrBpoG7kij4y2c3-xhcQSUf1RzyKCA9G2u2rF1UjBbeFQjCt3qdPgIb-3rqeyvNDkzOrUg?width=894&height=593&cropmode=none" alt="Resultado de ejecutar cl código anterior" class="alignnone size-full">

A pesar de tener ya el navegador junto con el acceso a la web que nos interesa, debemos implementar un mecanismo que nos permita esperar a que termine de cargar la página antes de seguir trabajando. Lo anterior podemos resolverlo utilizando un simple **while** y **Start-Sleep** mientras se encuentre el estado *Busy*:

{% highlight posh %}
while($ie.Busy) {Start-Sleep -Milliseconds 100}
{% endhighlight %}

Ahora que tenemos este gran avance, debemos conocer como hay que hacer para interactuar con los campos de búsqueda; el campo donde ingresamos el valor de la búsqueda y el botón para realizarla. Esto lo vamos a realizar por medio de las herramientas de desarrollador. Accedemos a ellas desde el navegador con la tecla F12:

<img src="https://q16ppq.ch.files.1drv.com/y4mXDHEAm_HFjHs_62-hbXAlIH__xU2Cvbxbyunwqvf4trk7-j3wM-yTQlkpIZdFCY7vI7maMMZjZ34RysbnNCcQ1csw9cerl1BR3L_FRbTR5vz3Q3rxuhrQzKDhAl8Kb69Cy_4kTcpZIhBxeWr1sa4GIm3jcc8VXIdhecqquzKYwxZfhCVw5nKueLJSk75iqF_mEYRDoVsUphm3K9L_ONOMA?width=839&height=593&cropmode=none" alt="Herramientas de desarrollador" class="alignnone size-full">

Usando las Dev Tools vamos a poder encontrar la información que necesitamos sobre los elementos con los que debemos interactuar. Para ello vamos a seleccionar la barra de búsqueda y hacemos clic derecho sobre ella para seleccionar la opción **Inspect element**. Como resultado de lo anterior, dentro de las Dev Tools vamos a ver resaltado un bloque de código, que corresponde al elemento de la web (barra de búsqueda). En la siguiente imagen se resalta con verde el valor que nos interesa para trabajar:

<img src="https://q16qpq.ch.files.1drv.com/y4m70jm0oxA7iETWQ-THaZYag_qNERjIyL_xaP-1YC046495ZwYxVKVeF-XZ_lGhEi9SQX24xhiM6vRTX-mxh5SLiSMyg0oX_Oka8cBFcaxQaKVXCmfDOKOOB5Tx7ikWRhYIDLFMlgVP9XNGJQMJtRvVyFmLGsmX_s7w7A4d3VtrjEFksUpuSnZcipCNe4I-HM5fJWKzIuZmMJWkGsKt8k_Ng?width=839&height=593&cropmode=none" alt="Inspect element" class="alignnone size-full">

Ese valor resaltado en verde es el **Id** del elemento, el cuál es único. Nos sirve para poder identificarlo dentro de la página web, de la siguiente manera:

{% highlight posh %}
$doc = $ie.Document
  $searchBarId = "masthead-search-term"
  $doc.getElementById($searchBarId)
{% endhighlight %}

Ahora vamos a hacer lo mismo para el botón de búsqueda y adicionamos, al bloque anterior, el valor que nos interesa buscar en Youtube:

{% highlight posh %}
$doc = $ie.Document
  $searchBarId = "masthead-search-term"
  $doc.getElementById($searchBarId).value = "PowerShell"
  $buttonId = "search-btn"
  $doc.getElementById($buttonId)
{% endhighlight %}


Y listo! Resta sumar todo en una función e invocar el método *click()* como se detalla en el siguiente bloque para que todo funcione correctamente:

{% highlight posh %}
function Search-Youtube {
    param(
      [string]$Search
    )
    $searchBarId = "masthead-search-term"
    $buttonId = "search-btn"
    $ie = new-object -com "InternetExplorer.Application"
    $ie.navigate2("https://www.youtube.com/?hl=es&gl=ES")
    $ie.visible = $true
    while($ie.Busy) { Start-Sleep -Milliseconds 100 }
    $doc = $ie.Document
    $doc.getElementById($searchBarId).value = $Search
    $doc.getElementById($buttonId).click()
  }
{% endhighlight %}

Al ejecutar la función e invocarla de la siguiente manera:

{% highlight posh %}
Search-Youtube -Search "Trailer de la casa de papel"
{% endhighlight %}

Vamos a obtener lo siguiente:

<img src="https://q17apq.ch.files.1drv.com/y4mcJ78-ncHcxG2CU4EAF6mhsInaRMhMSt5jPoERrBguqLTPtZrgmpV9ZzxxjSKjraeNPCFuEueN5fvo4OtDZA_FNEbJU192zQsqvAn4PuuUyzObGZMDsjJ3UPq3E9NW4Rs00Ig8jtlqM0NhYMDmz81zBQ6WF8askb8nxTMX9omM1ugAJpmriOyOF32n-g9yWwFcFObul9vL3Vy7GdISfcimw?width=839&height=593&cropmode=none" alt="Resultado de la búsqueda del trailer de la casa de papel" class="alignnone size-full">

Happy scripting!