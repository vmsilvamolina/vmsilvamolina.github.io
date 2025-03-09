---
title: 'PowerShell - Montar imagen ISO'
date: 2015-03-12T21:02:46+00:00
author: Victor Silva
layout: post
permalink: /powershell-montar-imagen-iso/
dsq_thread_id:
  - "4482537832"
categories:
  - PowerShell
tags:
  - Cmdlets
  - ISO
  - Montar
  - Mount
  - Mount-DiskImage
  - VHD
---
A veces nos encontramos con necesidades muy variadas al momento de crear scripts y de tratar de automatizar cosas.

Cuando empezamos a meternos en el tema de automatizar, pasamos por una etapa en la cual queremos hacer todo por PowerShell y de manera automatica.

Hoy quiero compartir un simple, pero poderoso tip: _Montar una imagen ISO_.

Esta acción vamos a poder llevarla a cabo con el siguiente comando:

> [Mount-DiskImage](https://technet.microsoft.com/en-us/library/hh848706.aspx)

Y la sintaxis es bastante simple, si tenemos una ISO de nombre Imagen.iso en la carpeta C:\ISOS, para montarla debemos ejecutar:

{% highlight posh %}
Mount-DiskImage -ImagePath C:\ISOS\Imagen.iso
{% endhighlight %}

Listo!

También podríamos ejecutar el comando sin el parámetro de la siguiente manera:

{% highlight posh %}
Mount-DiskImage C:\ISOS\Imagen.iso
{% endhighlight %}

Destacar también que ese no es el único uso de este fabuloso comando, también nos permite montar discos virtuales! Para realizar esta acción debemos de tener privilegios administrativos.

Happy scripting!