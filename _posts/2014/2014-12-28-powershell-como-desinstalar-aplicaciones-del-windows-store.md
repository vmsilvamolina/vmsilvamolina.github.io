---
title: 'Desinstalar aplicaciones del Windows Store con PowerShell'
date: 2014-12-28T23:53:57+00:00
author: Victor Silva
layout: post
permalink: /powershell-como-desinstalar-aplicaciones-del-windows-store/
dsq_thread_id:
  - "4478386073"
categories:
  - PowerShell
  - Windows
tags:
  - Desinstalar
  - Get-AppxPackage
  - Remove-AppxPackage
  - Uninstall app
  - Windows Store
---
Todos sabemos que Windows 8/8.1 viene con aplicaciones ya instaladas del tipo "
metro"
. La mayoría no nos interesan. También tenemos el store que nos permite acceder a miles de aplicaciones para poder probar y ver cual nos gusta y/o sirve más.

Hoy quiero compartir como podemos hacer desde PowerShell para poder desinstalar aplicaciones instaladas del store de Windows.

Lo primero que debemos hacer es ejecutar PowerShell como administrador, haciendo clic derecho sobre el icono en la barra de tareas:

<img src="https://lh6.googleusercontent.com/-bUp1mDbQjaU/VMmOzEduQcI/AAAAAAAAGvE/3aPnOI-c9aM/w377-h255-no/PS_Uninstall_App_1.png" width="377" height="255" class="alignnone" />

Luego debemos ejecutar el comando [Get-AppxPackage](https://technet.microsoft.com/en-us/library/hh856044.aspx) con el parametro ***-AllUsers***

<img src="https://lh3.googleusercontent.com/-80JpltekL2M/VMmYH4i4dqI/AAAAAAAAGxQ/kN7eK2jBsk0/w573-h440-no/PS_Uninstall_App_2.png" width="573" height="440" class="alignnone" />

Como resultado, nos mostrará todas las aplicaciones del store instaladas en nuestro equipo. Para poder observar mejor los datos, podemos filtrar las propiedades y presentarlas por medio del **_Out-GridView_** con la siguiente línea:

{% highlight posh %}
Get-AppxPackage -AllUsers | Select-Object -Property Name, Architecture, Version | Out-GridView
{% endhighlight %}

Quedando así:

<img src="https://lh4.googleusercontent.com/-lQNmW8inrpM/VMmYPDMO0bI/AAAAAAAAGxA/4qxGkX1TtdI/w475-h524-no/PS_Uninstall_App_3.png" width="475" height="524" class="alignnone" />

Ahora bien, en mi caso quiero desinstalar la aplicación de facebook. Lo primero que debemos hacer es encontrar esta aplicación utilizando el comando anterior, agregando el parametro ***-Name*** y escribiendo entre asteriscos (*) la palabra *facebook* (que se que esta en el nombre de la aplicación).

<img src="https://lh6.googleusercontent.com/-OHevQ--QWNo/VMmXrkeywjI/AAAAAAAAGws/YMOePeG2zIc/w656-h253-no/PS_Uninstall_App_4.png" width="732" height="253" class="alignnone" />

Ok. Si ejecuto esto, me devuelve las propiedades de esta aplicación; como arquitectura, ruta de instaalción,etc. Pero yo quiero desinstalarla. Para ello agregamos al final del comando un pipeline con el comando [Remove-AppxPackage](https://technet.microsoft.com/en-us/library/hh856038.aspx) y el, si desean, el parametro ***-Confirm***, como en mi caso, quedando de la siguiente manera:

<img src="https://lh6.googleusercontent.com/-lo4ywkDntuI/VMmXri5CWDI/AAAAAAAAGwk/yXw7XC7kHQU/w695-h106-no/PS_Uninstall_App_5.png" width="732" height="106" class="alignnone" />

Luego de ejecutado el comando anterior, podemos quedarnos tranquilos que esa aplicación ya no se encuentra en nuestro sistema.

Happy scripting!