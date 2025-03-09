---
title: 'Office 365 - Descargar el instalador en modo offline'
date: 2014-06-21T23:14:44+00:00
author: Victor Silva
layout: post
permalink: /office-365-descargar-el-instalador-en-modo-offline/
dsq_thread_id:
  - "4471578479"
categories:
  - Office 365
tags:
  - Descargar Office 365
  - Instalador
  - Installer
  - Office 365
  - Offline Installer
  - Pro Plus
---
Al intentar buscar una manera de poder realizar este procedimiento no encontré nada especifico por lo que pretendo compartir la manera en que me funcionó a mi en lo personal.

Lo primero que debemos saber es que no vamos a poder descargar el instalador de Office desde el portal de Office 365, por lo que vamos a tener que descargar la herramienta de Microsoft: <a title="Descargar Office Deployment Tool for Click-to-Run " href="https://www.microsoft.com/en-us/download/details.aspx?id=49117" target="_blank">Office Deployment Tool for Click-to-Run</a>

Ya con la herramienta descargada, vamos a necesitar instalarla, y luego, modificar el archivo _**configuration.xml**_ para indicarle que es lo que vamos a hacer.

Así que resumiendo los pasos, serían los siguientes:

  * Descargar la herramienta del enlace anterior

  * Modificar el archivo ***configuration.xml***, sustituir el SourcePath y UpdatePath según corresponda en su caso:

{% highlight xml %}
<Configuration>
  <Add SourcePath="PATH_TO_YOUR_DOWNLOAD_FOLDER, e.g. E:Downloads" OfficeClientEdition="32" >
    <Product ID="O365ProPlusRetail">
      <Language ID="en-us" />
    </Product>
    <Product ID="VisioProRetail">
      <Language ID="en-us" />
    </Product>
  </Add>
  <Updates Enabled="TRUE" UpdatePath="PATH_TO_YOUR_DOWNLOAD_FOLDER, e.g. E:Downloads" />
  <Display Level="None" AcceptEULA="TRUE" />
  <!--  <Logging Name="OfficeSetup.txt" Path="%temp%" />  -->
  <!--  <Property Name="AUTOACTIVATE" Value="1" />  -->
</Configuration>
{% endhighlight %}

  * Finalmente, ejecutar desde una consola CMD el siguiente comando:

{% highlight bash %}
setup.exe /download configuration.xml
{% endhighlight %}

  * Esperar a que finalice la descarga (puede demorar dependiendo de la velocidad de descarga)

  * Para instalar, basta con ejecutar lo siguiente:

{% highlight bash %}
setup.exe /configure configuration.xml
{% endhighlight %}

Espero les sirva (lo van a utilizar cuando no tengan buena conexión a internet) :)

Happy scripting!