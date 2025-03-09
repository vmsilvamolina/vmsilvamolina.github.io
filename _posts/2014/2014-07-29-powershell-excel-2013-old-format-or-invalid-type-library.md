---
title: 'PowerShell - Excel 2013: Old format or invalid type library'
date: 2014-07-29T17:51:44+00:00
author: Victor Silva
layout: post
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

>   "Old format or invalid type library'

O para ser mas específico, el siguiente error:

<img class="alignnone" src="https://lh3.googleusercontent.com/-Gw7HzCald0E/VAo9XqF_frI/AAAAAAAAFok/e1nlajIqSQU/w877-h253-no/PS_ExcelError.png" alt="" width="877" height="253" />

Se puede estar dando por un error en la configuración de la "cultura".

En mi caso, este error se debió a que mi configuración de región estaba registrada como **es-UY** mientras que el idioma del Office estaba en inglés.

Como solución, tenemos el comando [Set-Culture](http://technet.microsoft.com/en-US/library/hh852137.aspx) que nos permite modificar nuestra configuración en una línea. De la siguiente manera:

{% highlight posh %}
Set-Culture en-US
{% endhighlight %}

Y listo, podemos empezar a ejecutar nuestro código sin problemas.

Si no conocemos cuál es nuestra configuración, tenemos otro comando (todos a partir de la versión 3.0 de PowerShell):

[Get-Culture](http://technet.microsoft.com/en-us/library/hh849930.aspx)

Espero haber ayudado con esta info.

Happy scripting!