---
title: 'Herramientas para troubleshooting en Lync Server'
date: 2014-11-15T14:04:26+00:00
author: Victor Silva
layout: post
permalink: /lync-herramientas-para-troubleshooting/
dsq_thread_id:
  - "4527671441"
categories:
  - Skype for Business Server
tags:
  - Lync Server
  - OCSLogger
  - Remote Conectivity Analyzer
  - Snooper
  - Solucionar problemas
  - Troubleshooting
---
Lync es un producto excelente, pero si no estamos muy acostumbrados a tratar con él puede parecer confuso en algunos aspectos. Uno de ellos es a la hora de realizar troubleshooting de la solución. Cuando se nos presenta un problema, tenemos que tener claro por donde comenzar y mejor aún, que herramientas tenemos a nuestro alcance para poder hacer esto de la mejor manera.

La primer herramienta que vamos a ver es un poco conocida para los que trabajan con Exchange: **_Microsoft Remote Connectivity Analyzer_**.

Esta herramienta (proporcionada por Microsoft) nos permite ver varios aspectos de lo que son registros en los DNS,comunicación, certificados publicos y demás. Para acceder simplemente debemos ingresar al siguiente [enlace](https://testconnectivity.microsoft.com/).

Otra herramienta indispensable es el kit para el administrador [Microsoft Lync Server 2013 Debugging Tools](http://www.microsoft.com/en-us/download/details.aspx?id=35453). Este paquete trae:

  * Snooper
  * OCSLogger
  * OCSTracer
  * OCSLoggerOCSTracerClsController.psm1

Basicamente este grupo de herramientas nos permite generar logs, visualizarlos y analizarlos, facilitando la implementación de Lync Server.

Happy scripting!