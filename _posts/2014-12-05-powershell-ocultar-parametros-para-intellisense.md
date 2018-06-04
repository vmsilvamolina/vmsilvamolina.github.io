---
title: 'PowerShell &#8211; Ocultar parámetros para IntelliSense'
date: 2014-12-05T20:03:25+00:00
author: Victor Silva
layout: single
permalink: /powershell-ocultar-parametros-para-intellisense/
dsq_thread_id:
  - "4505225347"
categories:
  - PowerShell
tags:
  - Funciones
  - Hide Parameter
  - Ocultar parámetro
  - PowerShell
---
Si bien esto no es algo extraordinario, me pareció interesante cuando lo leí desde este [enlace](http://blogs.technet.com/b/heyscriptingguy/archive/2014/12/03/powertip-use-powershell-to-hide-parameter-from-intellisense.aspx "PowerTip: Use PowerShell to Hide Parameter From IntelliSense").

La cosa es así: Tenemos una función a la cuál queremos declarar un parámetro que no aparezca al pulsar la tecla **_tab_**. Fin. Eso es todo. Para que nos sirve? Si trabajamos con funciones con muchos parámetros y debemos de ejecutar éstas en diferentes ocasiones, puede resultar práctico, tener parámetros ocultos, para poder simplificar la redacción o llamada de las funciones en ciertos casos.

Ahora bien, como lo hacemos? De la siguiente manera:

Primero definimos una función:

{% highlight posh %}
Function Test-OcultarParametro {
    [cmdletbinding()]
    Param (
        [parameter(DontShow)]
        $ParametroOculto,
        [parameter()]
        $ComputerName,
        [parameter()]
        $NuevoValor
    )
}
{% endhighlight %}

Ya con la función definida, resta tipear la función, dejar un espacio, tipear el signo <b>"-"</b> y pulsar tabulador para poder corroborar que el parámetro **_$ParametroOculto_** no aparece en las opciones 🙂

Happy scripting!