---
id: 444
title: 'Office 365 &#8211; Descargar el instalador en modo offline'
date: 2014-06-21T23:14:44+00:00
author: Victor Silva
layout: post
guid: http://blog.victorsilva.com.uy/?p=444
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
<span id="myAccountSubscriptionsSubscriberDetailsSubsNumber">Al intentar buscar una manera de poder realizar este procedimiento no encontré nada especifico por lo que prentendo compartir la manera en que me funcionó a mi en lo personal.<br /> </span><!--more-->

Lo primero que debemos saber es que no vamos a poder descargar el instalador de Office desde el portal de Office 365, por lo que vamos a tener que descargar la herramienta de Microsoft: <a title="Descargar Office Deployment Tool for Click-to-Run " href="http://www.microsoft.com/en-us/download/details.aspx?id=36778" target="_blank">Office Deployment Tool for Click-to-Run</a>

Ya con la herramienta descargada, vamos a necesitar instalarla, y luego, modificar el archivo _**configuration.xml**_ para indicarle que es lo que vamos a hacer.

Así que resumiendo los pasos, serían los siguientes:

  * Descargar la herramienta del enlace anterior

  * <span class="notranslate">Modificar el archivo <em><strong>configuration.xml</strong></em>, sustituir el SourcePath y UpdatePath según corresponda en su caso:</span>

<pre class="lang:xhtml decode:true">&lt;Configuration&gt;
	&lt;Add SourcePath="PATH_TO_YOUR_DOWNLOAD_FOLDER, e.g. E:Downloads" OfficeClientEdition="32" &gt;
		&lt;Product ID="O365ProPlusRetail"&gt;
			&lt;Language ID="en-us" /&gt;
		&lt;/Product&gt;
		&lt;Product ID="VisioProRetail"&gt;
			&lt;Language ID="en-us" /&gt;
		&lt;/Product&gt;
	&lt;/Add&gt;

	&lt;Updates Enabled="TRUE" UpdatePath="PATH_TO_YOUR_DOWNLOAD_FOLDER, e.g. E:Downloads" /&gt;
	&lt;Display Level="None" AcceptEULA="TRUE" /&gt;
  &lt;!--  &lt;Logging Name="OfficeSetup.txt" Path="%temp%" /&gt;  --&gt;
  &lt;!--  &lt;Property Name="AUTOACTIVATE" Value="1" /&gt;  --&gt;
&lt;/Configuration&gt;</pre>

  * Finalmente, ejecutar desde una consola CMD el siguiente comando:

<pre class="lang:xhtml decode:true">setup.exe /download configuration.xml</pre>

  * Esperar a que finalice la descarga (puede demorar dependiendo de la velocidad de descarga)

  * Para instalar, basta con ejecutar lo siguiente:

<pre class="lang:xhtml decode:true ">setup.exe /configure configuration.xml</pre>

&nbsp;

Espero les sirva (lo van a utilizar cuando no tengan buena conexión a internet)

Saludos,