---
title: 'PowerShell - Cambiar el nivel funcional de AD'
date: 2015-08-03T21:56:59+00:00
author: Victor Silva
layout: post
permalink: /powershell-cambiar-el-nivel-funcional-de-ad/
dsq_thread_id:
  - "4504995138"
categories:
  - Active Directory
  - PowerShell
tags:
  - Active Directory
  - Cmdlet
  - Get-ADForest
  - Nivel funcional
  - PowerShell
  - Set-ADForestMode
---
Active Directory posee diferentes niveles de funcionalidades que básicamente determinan las capacidades de dominio (o bosque) de _Active Directory Domain Services_ que están disponibles. A su vez, el nivel funcional determina cuales son los sistemas operativos Windows Server que tienen la posibilidad de ejecutar el rol de controlador de dominio del dominio o del bosque. Si bien limitan los SO soportados en los controladores no determinan ninguna restricción en las estaciones de trabajo o los servidores miembros.

Lo ideal es tener siempre el nivel funcional lo mas alto que el parque de servidores lo permita: esto hace que sea posible contar con la mayor cantidad de features y funcionalidades para poder utilizarlas e implementarlas en nuestro ambiente.

Por ello es que quiero comentarles brevemente como es que por medio de PowerShell podemos elevar el nivel funcional de nuestro bosque.

**Set-ADForest** es el cmdlet que nos permite llevar a cabo esta acción.

Lo que debemos ejecutar, sería lo siguiente:

{% highlight posh%}
Get-ADForest | Set-ADForestMode -ForestMode windows2012R2Forest –Confirm:$false
{% endhighlight %}

Con el primer cmdlet obtenemos el nombre para posteriormente ejecutar Set-ADForest y seleccionar el nivel funcional correspondiente.

Si tenemos el nombre NetBIOS del dominio, perfectamente podemos ejecutar lo siguiente:

{% highlight posh%}
Set-ADForestMode –Identity "NetBIOSname windows2012R2Forest –Confirm:$false
{% endhighlight %}

Happy scripting!