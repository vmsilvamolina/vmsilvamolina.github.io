---
title: SSH en PowerShell
date: 2017-08-13T12:05:31+00:00
author: Victor Silva
layout: post
permalink: /ssh-en-powershell/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"9702f1cf2854";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:64:"https://medium.com/@vmsilvamolina/ssh-en-powershell-9702f1cf2854";}'
dsq_thread_id:
  - "6177745255"
categories:
  - PowerShell
tags:
  - Open-SSH
  - PowerShell
  - SSH
---

Actualmente que nos encontramos en un mundo en donde cada vez más los sistemas a administrar son heterogeneos (hablando de las diferentes soluciones implementadas). Por ello hablar de SSH hoy por hoy es moneda corriente, también para los administradores Windows que no estaban muy acostumbrados a manejarse puramente de la consola. Por ello hoy hablar de SSH en PowerShell es algo que no podemos dejar pasar.

Dentro del mundo Windows existe un proyecto en particular, que cuenta con el apoyo de la comunidad de PowerShell, el cual es **Open-SSH**.

## Open-SSH

Lo primero que debemos saber de Open-SSH es que es un proyecto Open Source, que se encuentra activo desde 1999. Lo bueno de este proyecto es que los que están acostumbrados a usar Linux, van a utilizar la misma sintaxis para trabajar con Open-SSH.

La instalación la vamos a realizar utilizando _Chocolatey_, si no lo tienen instalado les comparto una publicación anterior en este blog sobre ello: [enlace](http://blog.victorsilva.com.uy/chocolatey/).

Para instalar Open-SSH, debemos ejecutar en nuestra consola de PowerShell:

{% highlight posh %}
choco install openssh -y
{% endhighlight %}

<img src="https://cu2uww-ch3302.files.1drv.com/y4mbfWGVLezj5iq_LnTx2031plu5_-K0byrhNDp-nRaJmVjvTWVpQqp41k4aF1DY-eH5ZEQ5q9D36B_pUWwHwOKabskd0uMeJBc3GVIZewoOXusrf7TyFeB8Q8iHHUF9TTRNfDWZ86m_ur3abQE49iLB4EMddSafOr8pZycP0yzCmH59LZfLbhbGeGTN9slXq5u8aO9k8a0HXSGY5rNd4WcVQ?width=859&#038;height=632&#038;cropmode=none" width="859" height="632" alt="SSH en PowerShell" class="alignnone size-full" />

Luego:

{% highlight posh %}
RefreshEnv
{% endhighlight %}
    

Para recargar las variables de entorno definidas.

> Nota a tener en cuenta:

A pesar de que debe quedar la variable de entorno lista, en lo personal recomiendo revisarlas de la siguiente manera:

{% highlight posh %}
$env:path
{% endhighlight %}

Y buscar si se encuentra **_C:\Program Files\OpenSSH-Win64_**, en caso que no se encuentre, hay que agregarla a mano:

{% highlight posh %}
$new_path = "$env:PATH;C:\Program Files\OpenSSH-Win64"
$env:PATH=$new_path
[Environment]::SetEnvironmentVariable("path", $new_path, "Machine")
{% endhighlight %}
    

Y verificamos:

<img src="https://cu2tww-ch3302.files.1drv.com/y4mUXOoUXq3GfWActLI2Q0-5ujHFwRESnFjxUPVbyNRg7_KQBncjhpPfLNqJ3V_N4r_yv-obFQdoryumxxY5JWj5eA_XPOv02gageaR1XaHu6d3QDV3YMWmX4YAVX4NnE3xLrexY6Xd9m2_bthGvhGI6R_olTfvPPjs97gnbxeSnes7wWJH1jl3oANoaWuIxYIcZJC9stv8IJr5HyGFXzkyvA?width=859&#038;height=322&#038;cropmode=none" width="859" height="322" alt="SSH en PowerShell" class="alignnone size-full" />

## Usando SSH en PowerShell

Ahora que tenemos instalado Open-SSH en nuestro sistema y, otro dato no menor, podemos utilizarlo desde PowerShell, vamos a compartir algunos comando útiles de su uso.

En primer lugar debemos definir como conectarnos a un servidor:

{% highlight posh %}
ssh remoteServer
{% endhighlight %}

En caso de contar con una clave _.pem_ para utilizar en la conexión:

{% highlight posh %}
ssh remoteServer -i "C:\Key.pem"
{% endhighlight %}

Happy scripting!