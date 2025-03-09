---
title: 'Skype for Business - Solicitud de credenciales en el Control Panel'
date: 2015-07-16T16:18:44+00:00
author: Victor Silva
layout: post
redirect_from: /skype-for-business-solicitud-de-credenciales-en-el-control-panel/
permalink: /sfb-control-panel-credentials/
dsq_thread_id:
  - "4472436215"
categories:
  - PowerShell
  - Skype for Business Server
tags:
  - Control Panel
  - CSCP Credentials
  - Sitio seguro
  - Split()
---
Luego de instalar el servidor de Skype for Business 2015, cuando ingresamos a la consola de administración (Control Panel) nos topamos con la solicitud de credenciales administrativas. Es decir, tenemos que ingresar las credenciales de administrador de la implementación.

Si ingresamos seguido, esto es molesto. Bastante molesto, por lo que quiero compartir un pequeño tip para que no nos pida las credenciales cada vez que necesitamos ingresar.

Para ello, desde las opciones de Internet Explorer, nos vamos a la pestaña **Seguridad**, luego a **Intranet local** y después a **Opciones avanzadas**. Situados en las opciones avanzadas, tendremos que agregar el sitio web de administración

En nuestro caso, debemos agregar **_https://FQDN\_del\_FE_**.

<img src="https://lh6.googleusercontent.com/-eIhkX5d5_MU/VaFluLX4bgI/AAAAAAAAHEA/z1vDM_N9L_U/w744-h524-no/SFB_CSCP_Credentials_1.png" width="744" height="524" class="alignnone" />

Con este pequeño truco, ya no va a ser necesario ingresar nuevamente las credenciales.

## Solución desde PowerShell

Ya explicado el Tip, voy a pasar a detallar la solución por medio de PowerShell. Para agregar un sitio dentro de la zona de Intranet local, debemos acudir al registro de Windows.

La ruta que almacena esta información es la siguiente:

> HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap

Dentro de esta ruta, se genera una carpeta con el nombre del servidor en cuestión y una subcarpeta indicando si es http o https. Para que quede un poco mas claro, vamos a detallar un ejemplo:

Supongamos que mi el FQDN de mi Front End es _Servidor01.victorsilva.interno_. Si queremos resolver el problema de la solicitud de credenciales desde las opciones de internet, tendría que agregar el sitio `https://servidor01.victorsilva.interno` a la zona de Intranet local. Ahora, como a nosotros nos gusta complicarnos un poco (y aprender 🙂 ) desde PowerShell tendríamos que generar en el registro lo siguiente:

<img src="https://lh5.googleusercontent.com/-BFida3WKZmM/VaFp90y1ArI/AAAAAAAAHEQ/Z4fAwh7K_EM/w677-h96-no/SFB_CSCP_Credentials_2.png" width="677" height="96" class="alignnone" />

Entonces, para generar lo anterior, tenemos que ejecutar lo siguiente:

{% highlight posh%}
Function Set-IntranetSite {
  Param (
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$ServerFQDN
  )
  $ServerName = $ServerFQDN.Split(".")[0]
  $Domain = $ServerFQDN.Split(".",2)[1]
  $RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains"
  New-Item $RegPath -Name $Domain
  $RegPath += "\" + $Domain
  New-Item $RegPath -Name $ServerName
  $RegPath += "\" + $ServerName
  New-ItemProperty $RegPath -Name "https" -Value 1 -PropertyType "DWord"
}
{% endhighlight %}

Es una función bastante simple y rústica, simplemente quería reflejar como poder resolver la situación desde la consola.

Happy scripting!