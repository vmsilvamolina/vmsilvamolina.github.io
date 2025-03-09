---
title: 'Azure Cloud Shell: Bash o PowerShell?'
date: 2017-07-08T11:09:41+00:00
author: Victor Silva
layout: post
permalink: /azure-cloud-shell/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";N;s:10:"author_url";N;s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";N;s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:4:"none";s:3:"url";N;}'
dsq_thread_id:
  - "6086239576"
categories:
  - Azure
  - PowerShell
tags:
  - Azure
  - Azure Cloud Shell
  - PowerShell
  - Shell
---

Hace un tiempo se presentó la _public preview_ de una de las features de Azure que más me ha llamado la atención. No por el hecho de que Azure no tenga buenas features, si no porque es una que considero clave a la hora de lograr una mejor adopción de la plataforma. Esta feature es **_Azure Cloud Shell_**.

## Qué es Azure Cloud Shell?

Según Microsoft:

> "Azure Cloud Shell is an interactive, browser-accessible shell for managing Azure resources."

Por lo que básicamente podemos decir que es una consola para administrar Azure desde la web! Eso significa que no va a ser necesario instalar el CLI en nuestras computadoras (o al menos puede sustituirse).

Ahora bien, que beneficios puede traer una consola dentro de nuestro navegador web? En realidad es mucho más que eso y por ello quiero destacar algunos puntos a tener en cuenta a la hora de hablar de Azure Cloud Shell y en particular que herramientas ofrece a la hora de administrar Azure:

  * Es un container!

  * Tiene la última versión de Azure CLI pre-instalada, en donde ya estamos conectados y listos para comenzar a trabajar.

  * Dentro de las herramientas que trae por defecto, se encuentran: Vim, Git y Python.

  * El directorio $home se encuentra respaldado en Azure utilizando Azure File Storage, por lo que es encesario contar con una _storage account_ para utilizar ésta funcionalidad.

Sobre el tema costo, adjunto una pequeña cita extraída de la Technet que aclara la situación:

> The machine hosting Cloud Shell is free, with a pre-requisite of a mounted Azure file share to persist your $Home directory. Regular storage costs apply.

Es decir que usar Azure Cloud Shell en sí no tiene costo, lo que tiene costo mínimo es utilizar los servicios de Storage de Azure para alojar nuestro directorio $Home.

Azure Cloud Shell está soportado para utilizarse en los navegadores Chrome, Firefox, Safari, IE y Edge. Aunque se recomienda utilizarlo en Chrome, Edge y Safari.

### Manos a la obra!

Ahora que hemos conocido un poco mejor la consola vamos a ver como podemos hacer para trabajar de forma más eficiente utilizando Azure Cloud Shell.

Al acceder a la consola vemos que realiza un proceso de preparación y conexión:

<img src="https://do2oww-ch3302.files.1drv.com/y4mkgEPrX3_Rnlc3nPVpagNAYxAoZrTLcfyLURnadtQnPzzHUJIKDVE4Wl1vNHf3ugMbr2kUGD47eIj9tF7Y2MDJThug-rERkfqX0BbwoXx0SPX2N4e8-N4D-hXWU6Cq_c8zzWT22bLZiEZmwlRtTUCGVMduY9RCwGTOh9TYfbfRtdYzCiajAZErFk1v1DNi2nxSdNjv12ro_aV1T-StucRbw?width=609&#038;height=401&#038;cropmode=none" width="609" height="401" alt="Azure Cloud Shell" class="alignnone size-medium" />

> Como indica la imagen, el acceso a Azure Cloud Shell con PowerShell se encuentra en Private Preview, para poder acceder es necesario registrarse en el siguiente enlace: <https://aka.ms/PSCloudSignup>

Ahora que nos encontramos conectados podemos comenzar a indagar que nos permite realizar la consola.

Si observamos la variable $home, vemos que se encuentra un directorio en particular: _C:\Users\ContainerAdministrator_. En caso de ejecutar _Get-WmiObject -class Win32_OperatingSystem_ vemos que devuelve una versión de Windows 10. La versión que indica la salida de la ejecución es la **Anniversary Update** (Build number 14393).

<img src="https://do2nww-ch3302.files.1drv.com/y4mMzfa3ZGjpVJ3YemnUZNd7EU_sZwVTAs-YCNs7YbGXLK4KN9PxA15ILfK9TdgzDZfn5I-hQ7F2WdEIl4_2XHgeFPS_hH8kbap0sHX3VKuqm8rVrlobn2GQckjjT_4jUdudP7_Q-McsCiJ4vzTofUp_PttC4tXZ61ajkZWaCBJlLbSAplwXTEeEgRiGecQOAp294_C_C83IDPbHGlELcP-sA?width=490&#038;height=283&#038;cropmode=none" width="490" height="283" alt="$home" class="alignnone size-medium" />

Una gran opción que tenemos en Azure Cloud Shell es la posibilidad de utilizar _dir_ para movernos en las suscripciones y recursos de Azure de forma ágil y sencilla, como muestra el GIF a continuación:

[<img src="http://blog.victorsilva.com.uy/wp-content/uploads/2017/07/Azure-Cloud-Shell.gif" alt="" width="800" height="450" class="aligncenter size-full wp-image-1459" />](http://blog.victorsilva.com.uy/wp-content/uploads/2017/07/Azure-Cloud-Shell.gif)

Por último, recordar que se encuentran disponibles los comandos de Azure CLI, como por ejemplo:

{% highlight posh s%}
az vm list -d -o table
{% endhighlight %}    

Que despliega en la consola las VMs que se encuentran desplegadas en nuestra suscripción en forma de tabla. Al comando anterior podríamos adicionarle el parámetro **-g**, que permite definir el _Resource Group_ al que queremos consultar.

Happy scripting!