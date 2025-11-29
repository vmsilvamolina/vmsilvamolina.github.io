---
title: 'Modificar el prompt en PowerShell'
date: 2018-05-17T22:09:26+00:00
author: Victor Silva
layout: post
permalink: /powershell-customizar-prompt/
excerpt: "PowerShell ofrece muchas maneras de hacernos felices y una de ellas es la customización de la consola. Hoy quiero compartir como modificar el prompt de nuestra consola para darle un toque más personalizado y/o diferente."
dsq_thread_id:
  - "4488031977"
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"b1706affbec0";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:78:"https://medium.com/@vmsilvamolina/powershell-customizar-el-prompt-b1706affbec0";}'
categories:
  - PowerShell
tags:
  - Consola
  - Custom
  - Customizar
  - PowerShell
---
PowerShell ofrece muchas maneras de hacernos felices y una de ellas es la customización de la consola 🙂

Hoy quiero compartir como modificar el prompt de nuestra consola para darle un toque más personalizado y/o diferente.

Así es como se ve por defecto:

<img src="https://r2fyaq.ch.files.1drv.com/y4mWN0PM0pTAbcGecYIbevdmUhmlXpbzJRviI1QMon6FRJV-FuCvbA_eybXjHQNWn1W22dzU6rULTr9mMA74DwS-1xL_5GqdyEH8alWLfroneQIFaj2Ysk1Gx7JDjMw4Cd7x0i4bCFhXlctrK_70HuUjKijzvQLKTCEOhqaeBJuik917NbLtkvvqhtsHlwYdoZbB0JXEqXa4qz3gq5xD-PVbw?width=859&height=232&cropmode=none" width="859" height="232" alt="Consola de PowerShell" class="alignnone" />

## Primeros pasos

Lo primero que me gustaría compartir es cómo hacer para poder modificar nuestro perfil en PowerShell, para ello, debemos situarnos en la ruta de nuestro perfil dentro de la carpeta documentos, ahí van a encontrar la carpeta _WindowsPowerShell_ y dentro de ella, el archivo **_Microsoft.PowerShell_profile.ps1_**

En mi caso la ruta completa es: **C:\Users\Victor\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1**

Ahora bien, teniendo ubicado el archivo a modificar vamos a ver algunas cosas.

Primero debemos definir, por ejemplo, una función en donde poder ubicar nuestros cambios. Para ser consecuente, voy a generar una función llamada **prompt**, donde le voy a indicar que me devuelta (return) el símbolo numeral (o sharp):

{% highlight posh%}
  function Prompt {
    return "#"
  }
{% endhighlight %}

Si guardamos los cambios y ejecutamos una nueva consola de PowerShell vamos a ver lo siguiente:

<img src="https://r2fzaq.ch.files.1drv.com/y4mB-Ka7l1N4ABUE7O-RarZ0mQ3Z4jSfeP0Fr5bdtyl-a4Y8v-oGT_3jsEPecRir7vhCylmswXftxsF3bFiRXT0_LA_uca4w-_NE8Rr0BCIx0kbi_KFblUIDZVq7kIO0SIzuqrcdkFiJoAQaAVl78wvB0LNbrzu4g5prcdSbv3nHp-yL276gKx3RGAiq-XpEZZe93HZZvWlLaU3a4e5SkhneQ?width=859&height=183&cropmode=none" width="859" height="183" alt="Consola con el # como prompt" class="alignnone" />

Ya con esto podemos hacer algunas modificaciones, como: `>` o `->`

O agregar una variable, de la siguiente manera utilizando la hora:

{% highlight posh%}
  function Prompt {
    Write-Host ("[") -nonewline
    Write-Host (Get-Date -format HH:mm:ss) -nonewline
    Write-Host ("] #") -nonewline
    return " "
  }
{% endhighlight %}

Dejando el símbolo numeral, como separador (para que quede más ordenado).

## Agregando colores

Teniendo la base anterior, podemos tomar la función y agregarle un poco de color y algún símbolo más:

{% highlight posh%}
  function Prompt { 
    Write-Host ("[") -nonewline -foregroundcolor DarkGray 
    Write-Host (Get-Date -format HH:mm:ss) -nonewline 
    Write-Host ("] ") -nonewline -foregroundcolor DarkGray 
    Write-Host ($PWD) -nonewline -foregroundcolor Green 
    Write-Host (" | ") -nonewline -foregroundcolor DarkGray
    Write-Host ("#") -nonewline -foregroundcolor Yellow
    return " "
  }
{% endhighlight %}

<img src="https://pmhpja.ch.files.1drv.com/y4mfulzS_kgC2eMS6GziSr3XxHJ7BRXwfVQP0MVE7Ie9M9PexLFSC7AMcNcJ23Zl79f0M6-kgJYL7Kaigft9ED-3lO_X6_ad0_MDTOabFegcsXc8tPZcsC8v_jr0nfmUC-X2e2sKJ5yixdVDMDdCCj5ZhYVXf2SneqNEGxNvz3GkKL6G9bL8xX9PU6-vQRsEbIGAiLpwzz0c8Ixib2JRPrgUw?width=859&height=218&cropmode=none" width="859" height="218" alt="Prompt con hora, ubicación y #" class="alignnone" />

## Cambiando el título de la ventana

También podemos hacerle cambios visuales al título de la ventana, como en este ejemplo, agregando mi nombre y la versión de PowerShell:

{% highlight posh%}
  (Get-Host).UI.RawUI.WindowTitle =  "Victor" + " (v" + (Get-Host).Version + ")"
{% endhighlight %}

<img src="https://pmhqja.ch.files.1drv.com/y4mFTioXxU7DuRaY_edOaxhYou8eA3I3jpKLaDfN0JgUVOuoB7uZFqXFwVHjwdpIwn7cADi3zA2ZPNE7lIi8QkllAyLpejYZGi5w_QZPACW1oqRYQ_xZ04aNOm3_Q90gcz-lLaj60CdP2UOhBv_od_kaB9bykfXOT-kvBYV7V7l8ynpkCkaazFXLWi_hW_jcMCIGsBbPjxzYXF9azuUI4CUqA?width=859&height=218&cropmode=none" width="859" height="218" alt="Título cambiado" class="alignnone" />

## Revisando privilegios

Adicional a lo anterior podemos realizar una comprobación de privilegios, comprobando si el usuario ejecutó la sesión como administrador con la siguiente función:

{% highlight posh%}
  function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
  }
{% endhighlight %}

Y agregando lo anterior a otro ejemplo de customización del prompt:

{% highlight posh%}
  function prompt {
    if (Test-Administrator) {  # Use different username if elevated
      Write-Host "[Adm] " -NoNewline -ForegroundColor White
    }

    Write-Host "$ENV:USERNAME" -NoNewline -ForegroundColor Green
    Write-Host "@" -NoNewline
    Write-Host "$ENV:COMPUTERNAME" -NoNewline -ForegroundColor Green

    Write-Host " : " -NoNewline
    Write-Host $($(Get-Location) -replace ($env:USERPROFILE).Replace('\','\\'), "~") -NoNewline
    Write-Host " : " -NoNewline
    Write-Host (Get-Date -Format G) -NoNewline -ForegroundColor Gray
    Write-Host " : " -NoNewline

    Write-Host ""

    return "> "
  }
{% endhighlight %}

El resultado es:

<img src="https://q17urw.ch.files.1drv.com/y4mtDlJzFE8uoX75O69rWOKC9PwxwvmsSX2VraL-zk7TSO3uxzgo5tjBx_xa5TETbACwWnPfRt3Cy3GEbsoKCV41F23bZDIRrPlepfdsfeDhAfBD-ooTprAdE1nNq2zHd2bfq4lY2ruuGNXVZSf__SC43SXNLSqXUlSRIZr9F9L122-Z67_542o0-0-Q5stQk4bkXwuVL1TowuwS5eyt3pxWA?width=859&height=218&cropmode=none" width="859" height="218" alt="Comprobación de elevación de permisos" class="alignnone size-medium" />

Happy scripting!