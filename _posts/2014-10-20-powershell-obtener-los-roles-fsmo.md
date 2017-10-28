---
id: 611
title: 'PowerShell &#8211; Obtener los roles FSMO'
date: 2014-10-20T18:59:49+00:00
author: Victor Silva
layout: post
guid: http://blog.victorsilva.com.uy/?p=611
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
Los experimentados en Active Directory, recordarán que para obtener los controladores de dominio que tienen en su haber los roles FSMO debiamos ejecutar lo siguiente:

`NETDOM QUERY FSMO`

Y conestoobteniamos una lista con los controladores y sus roles efectivamente.

Pero este blog pretende evangelizar el uso de Windows PowerShell, por lo que paso a detallar como sería el procedimiento para obtener los datos anteriores pero desde nuestra consola amiga:

<pre>Get-ADDomain | Select-Object InfrastructureMaster, RIDMaster, PDCEmulator</pre>

<pre>Get-ADForest | Select-Object DomainNamingMaster, SchemaMaster</pre>

<pre>Get-ADDomainController -Filter * | Select-Object Name, Domain, Forest, OperationMasterRoles | Where-Object {$_.OperationMasterRoles} | Format-Table -AutoSize</pre>

Fácil, no?

Saludos,