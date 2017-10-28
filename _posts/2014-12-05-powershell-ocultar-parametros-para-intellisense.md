---
id: 615
title: 'PowerShell &#8211; Ocultar parametros para IntelliSense'
date: 2014-12-05T20:03:25+00:00
author: Victor Silva
layout: single
guid: http://blog.victorsilva.com.uy/?p=615
permalink: /powershell-ocultar-parametros-para-intellisense/
dsq_thread_id:
  - "4505225347"
categories:
  - PowerShell
tags:
  - Funciones
  - Hide Parameter
  - Ocultar parametro
  - PowerShell
---
Si bien esto no es algo extraordinario, me pareció interesante cuando lo leí desde este [enlace](http://blogs.technet.com/b/heyscriptingguy/archive/2014/12/03/powertip-use-powershell-to-hide-parameter-from-intellisense.aspx "PowerTip: Use PowerShell to Hide Parameter From IntelliSense").

La cosa es así: Tenemos una función a la cuál queremos declarar un parametro que no aparezca al pulsar la tecla **_tab_**. Fin. Eso es todo. Para que nos sirve? Si trabajamos con funciones con muchos parametros y debemos de ejecutar éstas en diferentes ocasiones, puede resultar práctico, tener parametros ocultos, para poder simplificar la redacción o llamada de las funciones en ciertos casos.

Ahora bien, como lo hacemos? De la siguiente manera:

Primero definimos una función:

<pre>Function Test-OcultarParametro {
    [cmdletbinding()]
    Param (
        [parameter(DontShow)]
        $ParametroOculto,
        [parameter()]
        $ComputerName,
        [parameter()]
        $NuevoValor
    )
}</pre>

Ya con la función definida, resta tipear la función, dejar un espacio, tipear el signo **&#8220;-&#8220;** y pulsar tabulador para poder corroborar que el parametro **_$ParametroOculto_** no aparece en las opciones 🙂

Saludos,