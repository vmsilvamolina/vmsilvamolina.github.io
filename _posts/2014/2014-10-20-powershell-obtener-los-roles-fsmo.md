---
title: 'PowerShell - Obtener los roles FSMO'
date: 2014-10-20T18:59:49+00:00
author: Victor Silva
layout: post
permalink: /powershell-obtener-los-roles-fsmo/
dsq_thread_id:
  - "4528066059"
categories:
  - PowerShell
  - Windows Server
tags:
  - FSMO Roles
  - PowerShell
---
Los experimentados en Active Directory, recordarán que para obtener los controladores de dominio que tienen en su haber los roles FSMO deberíamos ejecutar lo siguiente:

{% highlight posh%}
NETDOM QUERY FSMO
{% endhighlight %}

Y con esto obtendremos una lista con los controladores y sus roles efectivamente.

Pero este blog pretende evangelizar el uso de Windows PowerShell, por lo que paso a detallar como sería el procedimiento para obtener los datos anteriores pero desde nuestra consola amiga:

{% highlight posh %}
Get-ADDomain | Select-Object InfrastructureMaster, RIDMaster, PDCEmulator
{% endhighlight %}

{% highlight posh %}
Get-ADForest | Select-Object DomainNamingMaster, SchemaMaster
{% endhighlight %}

{% highlight posh %}
Get-ADDomainController -Filter * | Select-Object Name, Domain, Forest, OperationMasterRoles | Where-Object {$_.OperationMasterRoles} | Format-Table -AutoSize
{% endhighlight %}

Fácil, no?

Happy scripting!