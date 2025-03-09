---
title: PowerShell DSC en Linux parte II
date: 2017-07-16T18:13:06+00:00
author: Victor Silva
layout: post
permalink: /dsc-en-linux-parte-ii/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"1623693099f9";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:79:"https://medium.com/@vmsilvamolina/powershell-dsc-en-linux-parte-ii-1623693099f9";}'
dsq_thread_id:
  - "6158969681"
categories:
  - DevOps
  - PowerShell
tags:
  - DevOps
  - Linux
  - PowerShell DSC
---

PowerShell DSC ya no es un producto nuevo, ya se ha consolidado como una gran herramienta de gestión de la configuración. Ahora también abarcando los sistemas Linux y cada vez con más fuerza. Por ello es que quiero hablar un poco más de este nicho, ya que es necesario estar a la altura a la hora de poder implementar DSC en Linux y no fracasar en el intento.

Como recordatorio quiero compartir el [enlace](http://blog.victorsilva.com.uy/powershell-dsc-linux/) a mi entrada anterior sobre DSC en Linux para estar nivelados en conceptos y terminología.

Continuando con el tema en cuestión, vamos a definir nuestro objetivo de hoy: implementar un servidor web junto a una página HTML básica solamente con PowerShell.

## Archivo de configuración MOF

Como vimos anteriormente es necesario invocar en la configuración el módulo **nx**, responsable de poder realizar la interacción con nuestro servidor CentOS. Básicamente vamos a definir la receta de configuración que permite instalar el servidor web y generar un simple archivo _index.html_ como sitio estático:

{% highlight posh %}
Configuration DSCLinuxWeb {
    Import-DSCResource -Module nx

    Node "40.121.221.115" {
        nxPackage httpd {
            Name = "httpd"
            Ensure = "Present"
            PackageManager = "Yum"
        }

        nxService ApacheService {
            Name = "httpd"
            State = "Running"
            Enabled = $true
            Controller = "systemd"
            DependsOn = "[nxPackage]httpd"
        }    

        nxFile apache2File {
            Ensure = "Present"
            Type = "File"
            DestinationPath = "/var/www/index.html"
            Contents = '<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Webpage on Linux</title>
<style type="text/css">
.barra {
    background-color: #3A539B;
    color: #FFFFFF;
    line-height: 20px;
    padding: 15px;
    padding-left: 35px;
    border-radius:25px;
}
body {
    font-family: Segoe UI Light,SegoeUILightWF,Arial,Sans-Serif;
}
</style>
</head>
<body>
<h2 class="barra">Este servidor Apache y la página web fueron instalados con PowerShell DSC</h3>
</body>
</html>'
        }
    }
}
{% endhighlight %}

Después de definir el bloque de código anterior, debemos ejecutar el siguiente comando para generar los archivos necesarios:

{% highlight posh %}
DSCLinuxWeb -OutputPath:"C:\DSCLinux"
{% endhighlight %}

## Aplicar la configuración al servidor Linux

Para poder aplicar la configuración al servidor debemos ejecutar en el equipo Windows (cliente en esta oportunidad) lo siguiente:

{% highlight posh %}
$Node = "40.121.221.115"
$Credential = Get-Credential
$opt = New-CimSessionOption -UseSsl:$true -SkipCACheck:$true -SkipCNCheck:$true -SkipRevocationCheck:$true
$Sess=New-CimSession -Credential:$credential -ComputerName:$Node -Port:5986 -Authentication:basic -SessionOption:$opt -OperationTimeoutSec:90
{% endhighlight %}
    

Y por último debemos ejecutar lo siguiente para aplicar la configuración en el servidor Ubuntu:

{% highlight posh %}
Start-DscConfiguration -Path:"C:\DSCLinux" -CimSession:$Sess -Wait -Verbose
{% endhighlight %}
    

Si todo lo que hemos realizado, ha concluido correctamente vamos a poder abrir un navegador y acceder a la IP de nuestro servidor, para encontrarnos con lo siguiente:

<img src="https://cu2www-ch3302.files.1drv.com/y4muFSjSLH0vAT4qfjUmDtPrg3gTiZUBaKCwk0sHfPKcYj1bIjSw8cjC4jGKE7W4O454H0VNhYxpVuGG80xfmnyK-uQSDiYwyJVa2ZP2ix4uzVjBXR4kI1mPLaa-RE5EgygmZ28sV0OaOJI82Awx_W21DfalXwTXM3jKO_CLjepmgj7if1oKu-lACWjvAAdlyhkQJkc1eWBwbKjRQpWcCsEsA?width=824&#038;height=583&#038;cropmode=none" width="824" height="583" alt="PowerShell DSC en Linux: Web Server" class="alignnone size-full" />

Nuestro servidor web apache, con nuestro sitio funcional, todo gracias a PowerShell DSC.

Happy scripting!