---
title: Comprobar Hyper-V desde Pester
date: 2017-03-04T00:17:39+00:00
author: Victor Silva
layout: post
permalink: /comprobar-hyper-v-desde-pester/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"f315c62dd804";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:77:"https://medium.com/@vmsilvamolina/comprobar-hyper-v-desde-pester-f315c62dd804";}'
dsq_thread_id:
  - "6037089930"
categories:
  - PowerShell
tags:
  - Hyper-V
  - Pester
  - Pester Framework
  - PowerShell
  - Test
---
## Pester

Hace un tiempo escribí un post sobre que era [Pester](http://blog.victorsilva.com.uy/pester-framework/) y como funcionaba este gran proyecto dentro de PowerShell.

Básicamente, Pester es un framework de testing unitario, que permite comprobar el correcto funcionamiento de cierto código de forma aislada.

En esta oportunidad, quiero compartir un pequeño test para comprobar Hyper-V desde Pester. Obteniendo como resultado de la ejecución del mismo si lo servidores especificados se encuentran activos.

## Test

Para ello vamos a definir el siguiente bloque de código que enlista y describe los componentes que son parte activa del servidor y las comprobaciones necesarias:

{% highlight posh %}
#Requires -RunAsAdministrator
#Requires -Modules Pester
#Requires -Version 4.0

<#
.Synopsis
    Test de validación operativa para Microsoft Hyper-V
.DESCRIPTION
    Se requiere que la cuenta que ejecuta el test tenga privilegios administrativos locales sobre los servidores especificados. 
    .EXAMPLE
    Invoke-Pester -Script .\HyperV.Tests.ps1
.NOTES
    Ejecutar bajo la propia responsabilidad
.FUNCTIONALITY
    Test de validación funcional
#>

Describe "Basic validation of the Hyper-V servers" {
    $Servers = @('HV-01','HV-02')

    foreach ($ComputerName in $Servers) {
    $Session = New-PSSession -ComputerName $ComputerName

    It "The Hyper-V VM Management service on $ComputerName should be running" {
        (Invoke-Command -Session $Session {Get-Service -Name  vmms}).status |
        Should be 'Running'
    }

    It "The Windows Management Instrumentation service on $ComputerName should be running" {
        (Invoke-Command -Session $Session {Get-Service -Name winmgmt}).status  |
        Should be 'Running'
    }

    It "The Get-VMHost cmdlet on $ComputerName should not throw any errors" {
        {Invoke-Command -Session $Session {Get-VMHost}} |
        Should Not Throw
    }

    It "The Get-VM cmdlet on $ComputerName should not throw any errors" {
        {Invoke-Command -Session $Session {Get-VM}} |
        Should Not Throw
    }


    Remove-PSSession -Session $Session

    }
}
{% endhighlight %}
    

Al inicio del script se detalla el módulo requerido, versión y permisos necesarios para ser ejecutado.

Posteriormente quiero compartir el resultado de la ejecución del test en mi Notebook, ya que tiene el rol de Hyper-V habilitado, resultando la siguiente salida en consola:

<img src="https://du0zfw-ch3302.files.1drv.com/y4m9QVsn2sEHdOD7H7hcsNA0hvXlJVUX-1kX1KUzlak6YhoVjDYRYAoR1OjBpinmvfV_u2h4NT6lpXbwu0dQZhGhwYB9eQECarHUp9zeBBxiUbPX1HYoik_kXE2JR1LjL7bEbCxI8d-lpE6pT214M017URF4Ch_roJN1YoVFAToIeCt2zKeC1Rt1UkFHdM4dBW5XAjCU4nrnsufL_fFt_a5yg?width=859&#038;height=289&#038;cropmode=none" width="859" height="289" alt="Comprobar Hyper-V desde Pester" class="alignnone size-medium" />

Happy scripting!