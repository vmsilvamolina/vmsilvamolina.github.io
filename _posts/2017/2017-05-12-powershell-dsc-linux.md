---
title: PowerShell DSC en Linux (Primeros pasos)
date: 2017-05-12T20:45:04+00:00
author: Victor Silva
layout: post
permalink: /powershell-dsc-linux/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"da66d1a412fb";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:85:"https://medium.com/@vmsilvamolina/powershell-dsc-en-linux-primeros-pasos-da66d1a412fb";}'
dsq_thread_id:
  - "5993583276"
categories:
  - PowerShell
tags:
  - Automatización
  - Desire State Configuration
  - Linux
  - PowerShell DSC
  - PowerShell DSC en Linux
  - Scripting
---
PowerShell DSC en Linux es algo que todos los administradores que usamos PowerShell y que trabajamos sobre ambientes heterogéneos aparece como una luz en la oscuridad. Las posibilidades que aparecen a la hora de generar plantillas de configuración para Linux, permiten seguir optimizando recursos a la hora de realizar las tareas del día a día.

## Administrar Linux con PowerShell DSC

Para la demostración que vamos a presentar, usaremos CentOS 7, y vamos a configurar aspectos básicos de la instalación como son el nombre y la IP para demostrar el potencial que ofrece PowerShell DSC no sólo en ambientes Microsoft puros.

## Versiones soportadas

Comparto una lista donde se muestran las versiones soportadas de Linux para poder ser administradas desde PowerShell DSC:

  * CentOS 5, 6, and 7 (x86/x64)
  * Debian GNU/Linux 6, 7 and 8 (x86/x64)
  * Oracle Linux 5, 6 and 7 (x86/x64)
  * Red Hat Enterprise Linux Server 5, 6 and 7 (x86/x64)
  * SUSE Linux Enterprise Server 10, 11 and 12 (x86/x64)
  * Ubuntu Server 12.04 LTS, 14.04 LTS, 16.04 LTS (x86/x64)

## Instalación de OMI y DSC

Dentro de los requerimientos necesarios para la instalación de DSC se encuentra OMI ([Open Management Infraestructure](https://collaboration.opengroup.org/omi/)). A su vez existen algunas dependencias requeridas para su correcto funcionamiento:

[Required packages](https://github.com/Microsoft/PowerShell-DSC-for-Linux#requirements)

Ahora sí, para instalar OMI y DSC en CentOS es necesario ejecutar los siguientes comandos:

{% highlight posh %}
wget https://github.com/Microsoft/omi/releases/download/v1.1.0-0/omi-1.1.0.ssl_100.x64.rpm
{% endhighlight %}

<img src="https://ep0xfw-ch3302.files.1drv.com/y4m9MN3MJ_GWf0DPTWhMhNZbqvZ1mNJ_Q2pf3s34d9wgsqnLDTUqUy4ct4yOIt7IiTJJZ4D5Rh7-yNid4jv7-VJV3Jtmq5JMnpGZprhO1WwotJWWPhMERe849CwVQ9DLTVNssQoFNc_9CCyZFIdIcIX290XenB1o-5xckwi0PtVeidater5QgrkZdJtDSdbgvxjAcWr2SNu3K-0NltGOryR0A?width=1154&#038;height=382&#038;cropmode=none" width="1154" height="382" class="alignnone size-medium" />

{% highlight posh %}
wget https://github.com/Microsoft/PowerShell-DSC-for-Linux/releases/download/v1.1.1-294/dsc-1.1.1-294.ssl_100.x64.rpm
{% endhighlight %}

<img src="https://ep0yfw-ch3302.files.1drv.com/y4m5By5QI-6JJ3-QBdAI6H3xNFLzCZyoHirPffyVe0FONd9Lo1LsAqflElzsCN3pnz303eG5-pPZE5hyKmtJuGilEWYVFQ3Xut2qfDMgoHUE-TFOSbKK-iW2iDmXvKoUBf5kbha7h4lzGUKonWGa29D4G3rbZ9ewCblwRTL0iR6KtPqORkZTgfOFon24AkJ21a_hj6toShevog9HeI_YMl38g?width=1152&#038;height=492&#038;cropmode=none" width="1152" height="492" class="alignnone size-medium" />

{% highlight posh %}
sudo rpm -Uvh omi-1.1.0.ssl_100.x64.rpm dsc-1.1.1-294.ssl_100.x64.rpm
{% endhighlight %}

<img src="https://ep0wfw-ch3302.files.1drv.com/y4m8uJ0ZIS8U5TJgwIe3el1tizrzSROQdH9dFODDtZQLRmIxE-flVopGH6x9VWYGuzQ0w1-WO_uCxRC8U_PdkMpxs-349JN146Cg6cFyHzSo1WL0oYMDn9-ZGvVyF1sCYKw4Blqd6gUnGOcJlSFz4xXKWMbtcuYGib4zZs3pcQ3_u_E73EgJyvSGSi6xhn0nxLyXJhl9Tk5i45G2uIZe2m02Q?width=1135&#038;height=464&#038;cropmode=none" width="1135" height="464" class="alignnone size-medium" />

> Se utilizan los enlaces con **_ssl_100_**, debido a que la versión de CentOS 7 ya viene con OpenSSL 1.0. En caso >de desconocer que versión de OpenSSL se encuentra instalda en el equipo, es necesario ejecutar:

{% highlight posh %}
openssl version
{% endhighlight %}    

## Generando el archivo de configuración MOF

Ya con todo instalado y listo, es necesario generar los archivos de configuración que permitan modificar nuestro servidor CentOS.

Si vamos a trabajar desde una máquina con Windows, es necesario contar con una versión igual o superior de PowerShell v4.0. En segundo lugar también se requiere disponer del módulo **_nx_**, llamado Linux Resource Provider MOF:

{% highlight posh %}
Install-Module nx
{% endhighlight %}    

Y vamos a permitir esa instalación desde la galería de PowerShell, confirmando el mensaje que aparece.

Para comenzar a trabajar sobre la configuración de nuestro servidor de Linux, vamos a invocar el módulo _nx_ en la configuración de nuestro archivo DSC, de la siguiente manera, siempre trabajando desde nuestro equipo con Windows y sobre la consola de PowerShell:

{% highlight posh %}
Configuration ExampleConfiguration{
    Import-DSCResource -Module nx
}
{% endhighlight %}

Ahora bien, vamos a probar con algo sencillo: vamos a generar un archivo con una cadena de texto. Para ello utilizaremos el siguiente fragmento de código, tomando lo detallado anteriormente:

{% highlight posh %}
Configuration LinuxConfiguration{
    Import-DscResource -Module nx

    Node  "192.168.1.21" {
        nxFile ExampleFile {
            DestinationPath = "/tmp/exampledsc"
            Contents = "Hello PoSh World `n"
            Ensure = "Present"
            Type = "File"
        }
    }
}

LinuxConfiguration -OutputPath:"C:\DSC"
{% endhighlight %}    

En el bloque anterior detallamos el uso del módulo de DSC para Linux y también en que nodo vamos a estar trabajando (en mi caso solamente ingresé la IP del server con CentOS). Luego se describe un archivo de prueba, con la ruta donde se va a generar y el texto que va a tener "
Hello PoSh World"
.

Si bien todo se encuentra controlado, tenemos que habilitar en el Firewall del servidor de Linux el puerto que vamos a utilizar para poder acceder, ejecutando:

{% highlight posh %}
firewall-cmd --add-port=5986/tcp --permanent
firewall-cmd --reload
{% endhighlight %}

## Aplicar la configuración al servidor Linux

Continuado a lo anterior debemos ejecutar en el equipo Windows lo siguiente:

{% highlight posh %}
#Servidor CentOS
$Node = "192.168.1.21"
#Credenciales para ingresar al servidor
$Credential = Get-Credential -UserName:"root" -Message:"Contraseña:"
#Definimos las opciones de SSL que usará la sesión (que queremos obviar por no confiar en la CA)
$opt = New-CimSessionOption -UseSsl:$true -SkipCACheck:$true -SkipCNCheck:$true -SkipRevocationCheck:$true
#Definimos la sesión para poder conectarnos con el servidor
$Sess=New-CimSession -Credential:$credential -ComputerName:$Node -Port:5986 -Authentication:basic -SessionOption:$opt -OperationTimeoutSec:90
{% endhighlight %}

Y por último:

{% highlight posh %}
Start-DscConfiguration -Path:"C:\DSC" -CimSession:$Sess -Wait -Verbose
{% endhighlight %}

Que si todo va OK, debería generar el archivo de ejemplo llamado **exampledsc** con el texto que definimos. Aquí la captura de pantalla que comprueba que ha funcionado correctamente:

<img src="https://ep0vfw-ch3302.files.1drv.com/y4m5TFcNhXW00lyLy_8k-BuM-kONirrpIxZmQRytgLYmFr78MG9lclBQOPnzK3riCttT1WQ8GLoMC47wvfQhkQzQIr1WWIfb1MEf2cXeHLk9LIPK-p6St7DdOQQK84XE6Eo3fILkyTliwlWyo7_-c7KThN8ZGrg13gpCbpGBLIxiBHQ6FNKiDPd5-_3aDi1oxtJJDI2V8GPh_8Pm8QvpHqL-Q?width=402&#038;height=226&#038;cropmode=none" width="402" height="226" alt="PowerShell DSC en Linux" class="alignnone size-medium" />

En próximas entregas vamos a ir avanzando en las configuraciones a realizar, así como en la complejidad de los escenarios.

Happy scripting!