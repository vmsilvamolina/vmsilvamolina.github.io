---
title: 'SQL Server - Does not support the language of the OS'
date: 2015-07-08T21:56:26+00:00
author: Victor Silva
layout: post
permalink: /sql-does-not-support-the-language-of-the-os/
dsq_thread_id:
  - "4482452570"
categories:
  - PowerShell
tags:
  - SQL Server
  - PowerShell
  - Support OS
---
En varias ocasiones nos encontramos con comportamientos que son raros, que se salen de lo normal, cuando nosotros consideramos que debería de estar todo bien.

Esto me pasó al intentar instalar un SQL Server 2008 R2 en español, en un Windows Server 2008 R2 en español:

<img src="https://lh5.googleusercontent.com/-hYWevoCo4gY/VZ2yL8E5tFI/AAAAAAAAHCk/jclQ5eqV9Ak/w371-h136-no/SQL_Language_1.png" width="371" height="136" class="alignnone" />

_SQL Server setup media does not support the language of the OS or does not have ENU localized files. Use the matching language-specific SQL Server media or change the OS locale through control panel._

Pff! Cómo? Si todo es español? Revisando en foros de soporte, encontré una respuesta a este problema. Resulta que si no es **español de España** no cuenta. :)

Modificamos en el panel de control el idioma, para que sea español de España: la opción es Español (España)

<img src="https://lh4.googleusercontent.com/-NhJw98bshxc/VZ2z1-kn4zI/AAAAAAAAHC4/JJqrz34HTP8/w766-h533-no/SQL_Language_2.png" width="766" height="533" class="alignnone" />

Volvemos a intentar... y todo de maravilla!

Y como no puede ser de otra manera, desde PowerShell podemos hacer una función bien simple para hacer el cambio correctamente:

{% highlight posh%}
Function Change-Language {            
  param ($Language)            
  Set-ItemProperty "HKCU:\Control Panel\International" -Name "LocaleName" -Value $Language 
}            

Change-Language -Language "es-ES"
{% endhighlight %}

Happy scripting!