---
title: "Deshabilitar/Habilitar el proxy desde PowerShell"
author: Victor Silva
date: 2018-11-22T22:21:00+00:00
layout: post
permalink: /deshabilitar-habilitar-proxy/
excerpt: "Hace un par de post comenté que estuve trabajando detrás de un proxy corporativo, y estos días he vuelto a estar en la misma condición. Por lo que al llevarme el equipo a mi casa, me encontraba con la necesidad de estar modificando la configuración del proxy en Internet Explorer para poder nevegar tranquilo."
categories:
  - PowerShell
tags:
  - PowerShell
  - Internet Explorer proxy
  - proxy
---

Hace un par de post comenté que estuve trabajando detrás de un proxy corporativo, y estos días he vuelto a estar en la misma condición. Por lo que al llevarme el equipo a mi casa, me encontraba con la necesidad de estar modificando la configuración del proxy en Internet Explorer para poder nevegar tranquilo.

Créanme si les digo que es una tarea que si se realiza un par de veces de forma repetida, para mí pasa a ser un enemigo y tengo que intentar automatizarla de alguna manera.

Windows establece su base de configuración en gran mayoría sobre el viejo y querido **registro**.

## Regedit, nunca pasa de moda...

Accedemos al registro con el super-mega-conocido `regedit` y realizando una simple búsqueda dentro de la ruta **HKEY_CURRENT_USER** (no es más que ingresar el valor del servidor proxy en el buscado) encontramos la siguiente configuración:

> HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings

Perfecto! Ahí está todo lo que necesitamos, solo resta ver que tenemos que modificar...

Lo primero que podemos observar es que la clave *ProxyEnable (REG_DWORD)* tiene el valor **1**. O sea que para poder deshabilitar el proxy, basta con cambiar el valor a 0. Para ello debemos ejecutar lo siguiente (como administrador):

{% highlight posh%}
  Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 0
{% endhighlight %}

Si revisamos dentro de la configuración de Internet Explorer, vamos a encontrarnos con que efectivamente se encuentra deshabilitado (sn borrar la configuración anterior).

Resulta más que obvio que para volver a habilitar el proxy se debe cambiar el valor a 1, ejecutando:

{% highlight posh%}
  Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 1
{% endhighlight %}

## Funciones para todos

Y con la información que recolectamos podemos armar las siguientes funciones para poder agregar a nuestro perfil y utilizarlas cuando sea necesario:

{% highlight posh%}
  Function Set-InternetProxy
  {
      [CmdletBinding()]
      Param(
          [Parameter(Mandatory=$True,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
          [String[]]$Proxy
      )

      Begin {
          $regKey="HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
      }
      
      Process {
          Set-ItemProperty -path $regKey ProxyEnable -value 1
          Set-ItemProperty -path $regKey ProxyServer -value $proxy
      }
      
      End {
          Write-Output "Se habilitó el proxy"
          Write-Output "Servidor:puerto = $proxy"
      }
  }


  Function Disable-InternetProxy
  {
      Begin {
          $regKey="HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
      }
      
      Process {
          Set-ItemProperty -path $regKey ProxyEnable -value 0 -ErrorAction Stop
      }
      
      End {
          Write-Output "Proxy is now Disabled"      
      }
  }
{% endhighlight %}

Happy scripting!