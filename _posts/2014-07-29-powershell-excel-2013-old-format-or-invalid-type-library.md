---
id: 504
title: 'PowerShell &#8211; Excel 2013: &#8220;Old format or invalid type library&#8221;'
date: 2014-07-29T17:51:44+00:00
author: Victor Silva
layout: single
guid: http://blog.victorsilva.com.uy/?p=504
permalink: /powershell-excel-2013-old-format-or-invalid-type-library/
dsq_thread_id:
  - "4531223485"
categories:
  - PowerShell
tags:
  - Excel
  - Get-Culture
  - Old format or invalid type library
  - PowerShell
  - Set-Culture
---
Si al intentar trabajar con scripts en Excel desde PowerShell , nos aparece un mensaje de error de este estilo:

> <p id="mt_title" class="title">
>   &#8220;Old format or invalid type library&#8221;
> </p>

O para ser mas especificos, el siguiente error:

<img class="alignnone" src="https://lh3.googleusercontent.com/-Gw7HzCald0E/VAo9XqF_frI/AAAAAAAAFok/e1nlajIqSQU/w877-h253-no/PS_ExcelError.png" alt="" width="877" height="253" />

Se puede estar dando por un error en la configuación de la &#8220;cultura&#8221;.

En mi caso, este error se debió a que mi confiugración de región estaba seteada como es-UY mientras que el idioma del Office estaba en inglés.

Como solución, tenemos el comando <a title="TechNet: Set-Culture" href="http://technet.microsoft.com/en-US/library/hh852137.aspx" target="_blank">Set-Culture</a> que nos permite modificar nuestra configuración en una línea. De la siguiente manera:

<pre class="lang:default decode:true  ">Set-Culture en-US</pre>

Y listo, podemos empezar a ejecutar nuestro código sin problemas.

Si no conocemos cuál es nuestra configuración, tenemos otro comando (todos a partir de la versión 3.0 de PowerShell):

<a title="TechNet: Get-Culture" href="http://technet.microsoft.com/en-us/library/hh849930.aspx" target="_blank">Get-Culture</a>

Espero haber ayudado con esta info.

Saludos,

&nbsp;