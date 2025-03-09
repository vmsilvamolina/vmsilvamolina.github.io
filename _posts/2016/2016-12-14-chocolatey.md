---
title: Chocolatey, el gestor de paquetes en Windows
date: 2016-12-14T19:22:23+00:00
author: Victor Silva
layout: post
permalink: /chocolatey/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"e06cc287943d";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:90:"https://medium.com/@vmsilvamolina/chocolatey-el-gestor-de-paquetes-en-windows-e06cc287943d";}'
dsq_thread_id:
  - "5420491301"
categories:
  - PowerShell
tags:
  - choco
  - Chocolatey
  - Gestor de paquetes
  - PowerShell
---
## Chocolatey?

Hoy vengo a compartir que en Windows hoy contamos con el proyecto [Chocolatey](https://chocolatey.org), que utiliza la infraestructura de paquetería NuGet para lograr este objetivo, que como he leído por ahí, es el apt-get de Windows.

Todos los que trabajan con Windows conocen que el proceso de instalar Software está atado a ejecutar asistentes de forma tediosa y se reducen simplemente a pulsar "
siguiente"
 para intentar completar el proceso lo antes posible. Esto obviamente en la mayoría de los casos.

Ahora bien, todos aquellos que trabajan con Windows pero manejan Linux (o al menos tienen algunos conocimientos) saben que cuentan con gestores de paquetes, que básicamente son repositorios de software que permiten instalar software por medio de la consola. Esto simplifica no solo el proceso de instalación, si no que los que deben instalar software bastante a menudo o de forma repetitiva valoran, y mucho, este tipo de herramientas.

Para más información del proyecto les dejo el repositorio en GitHub:
  
[https://github.com/chocolatey](https://github.com/chocolatey)

## Instalación

Para instalar Chocolatey en nuestros sistemas Windows el proceso se reduce a ejecutar sobre nuestra consola de PowerShell la siguiente línea:

{% highlight posh %}
iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex
{% endhighlight %}

Listo!

Ya contamos con Chocolatey para poder instalar nuestro software.

Pero que programas se encuentran disponibles para descargar e instalar? Al día de hoy se encuentran 4449 mantenidos por la comunidad, como por ejemplo Docker, Chrome, Skype, Git, etc. Además se integra con otras aplicaciones del tipo **_configuration manager_** como PowerShell DSC, Chef, Ansible, etc.

## Instalar software desde la consola

Para instalar un software o programa, como por ejemplo Chrome, basta con ejecutar desde la consola de PowerShell:

{% highlight posh %}
choco install googlechrome
{% endhighlight %}

Happy scripting!