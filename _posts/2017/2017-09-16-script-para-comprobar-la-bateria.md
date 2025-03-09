---
title: Script para comprobar la batería
date: 2017-09-16T14:30:06+00:00
author: Victor Silva
layout: post
permalink: /script-para-comprobar-la-bateria/
excerpt: "En el trabajo me cambiaron la notebook y eso genera un montón de cosas (buenas y malas); reinstalar software, acomodar algunas cosas y configurar otras tantas. Debido a que me gusta el scripting, tengo un script para ello."
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"eaebb029c11e";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:84:"https://medium.com/@vmsilvamolina/script-para-comprobar-la-bater%C3%ADa-eaebb029c11e";}'
dsq_thread_id:
  - "6231565601"
categories:
  - PowerShell
tags:
  - Pop up
  - PowerShell
  - Win32_Battery
  - WMI
---

En el trabajo me cambiaron la notebook y eso genera un montón de cosas (buenas y malas); reinstalar software, acomodar algunas cosas y configurar otras tantas. Debido a que me gusta el scripting, tengo un script para ello. Obviamente está escrito en PowerShell (acá el [enlace](https://gist.github.com/vmsilvamolina/e941b751f0d034400b885e369b4e0f77)) para no tener que recorrer el mismo camino todas las veces. También, al ser un equipo nuevo, siempre intentamos cuidarlo al máximo. Por lo tanto es que se me cruzó por la cabeza el problema de la batería (que fue uno de los motores impulsores al cambio), y el por qué no crear un script para comprobar la batería.

Charlando con un compañero llegamos a una conclusión inicial sobre el cuidado de las baterías. Para extender la vida útil de la batería es necesario monitorear los ciclos de conectar/desconectar a la corriente el equipo para que nunca llegue a menos del 20% de la carga y nunca supere el 80%. Esto en base a lecturas previas sobre el tema, conocimiento heredado de la vida y una pequeña investigación al momento de la charla.

Así que, sin tener mayor fundamento que lo expuesto anteriormente me dispuse a armar un script para monitorear el proceso de carga. Como consecuencia de lo anterior, al momento de llegar a los extremos definidos, genere un pop up indicando que debo tomar acciones.

## ¿Dónde consulto la información de la batería?

Tomando en cuenta mi acotado conocimiento sobre WMI, es posible que exista alguna clase que pueda ser mi punto de partida para empezar a recolectar datos. Efectivamente existe una clase que se llama **[Win32_Battery](https://msdn.microsoft.com/en-us/library/aa394074%28v=vs.85%29.aspx)** que nos comparte información sobre la batería. Ejecutando _Get-WmiObjet_ obtenemos lo siguiente:

{% highlight posh %}
Get-WmiObject Win32_Battery
{% endhighlight %}
    

En donde la propiedad **EstimatedChargeRemaining**, representa el valor que se indica en el ícono de batería en la barra de tareas:

<img src="https://pbocga-ch3302.files.1drv.com/y4m6eOZrhDP_VniIfRXR5LFN2_BgclLBL7VUR9LX-xOcnFhY9ozGT6ll5ObqJSSrhjHBRfLbIAEbDBGRGKZUWJ3vqOfbG3VPyi269zZUi7usz-jQkgog2dkXN1TMehPS-8uz_YGSUMsa_k3ePtEqdRpfflLuHHfL7SOLXRGofsFFGlCK0Uv9M_g4kHOxYMW-A5MVrZVI5Y5LoCibEXBoGy1rQ?width=897&#038;height=728&#038;cropmode=none" width="897" height="728" alt="Get-WmiObject Win32_Battery" class="alignnone size-full" />

Tener en cuenta que el otro indicador que tenemos que prestar atención es **BatteryStatus** que indica, según la documentación, el estado en que se encuentra la batería (si se encuentra descargándose y otras condiciones que no vienen al caso). Por tanto recomiendo que ejecuten lo siguiente, conectados a la corriente o solamente usando la batería:

## Script para comprobar la batería

Frente a la información anterior, podemos armar un simple script para comprobar la batería:

{% highlight posh %}
if ((Get-WmiObject Win32_Battery).BatteryStatus -ne 1) {
    if ((Get-WmiObject win32_battery).EstimatedChargeRemaining -gt 80) {
      Write-host "Desconectar de la corriente!"
    }
  } else {
    if ((Get-WmiObject win32_battery).EstimatedChargeRemaining -lt 20) {
      Write-host "Conectar el equipo!"
    }
  }
{% endhighlight %}

Debido al objetivo del post, vamos a continuar resolviendo el problema de los pop-ups Para ello existen varias maneras de resolver esto. En este post voy a compartir la que para mí es la más fácil:

{% highlight posh %}
$wshell = New-Object -ComObject Wscript.Shell
  $wshell.Popup("Desconectar la notebook",0,"Alerta",0x0 + 0x30)
{% endhighlight %}

<img src="https://pboaga-ch3302.files.1drv.com/y4m0BtLlEkuFG145ssS2C-wXXwNLAmALgvo4IbtPWPINqeotF1jdfAA4lsSbW44w6ExI2aLeQkEgRg_WxvR19QjwECUIujbGFM0C0hPF4EMb7GKydw4ModEnKv9ny6FYRH4Bvf5ePf8lS6pb5cwk5VHCvRMDtPJwS6sJTTx1nItFNiUc9q-HcLnUuVixEB8TzxDttbbWDrQIYlXeoVqcvS-Lg?width=992&#038;height=371&#038;cropmode=none" width="992" height="371" alt="Popup Method" class="alignnone size-full" />

Finalmente vamos a tener el siguiente script:

{% highlight posh %}
if ((Get-WmiObject Win32_Battery).BatteryStatus -ne 1) {
    if ((Get-WmiObject win32_battery).EstimatedChargeRemaining -gt 80) {
      $wshell = New-Object -ComObject Wscript.Shell
      $wshell.Popup("Desconectar de la corriente!",0,"Alerta",0x0 + 0x30)
    }
  } else {
    if ((Get-WmiObject win32_battery).EstimatedChargeRemaining -lt 20) {
      $wshell = New-Object -ComObject Wscript.Shell
      $wshell.Popup("Conectar el equipo!",0,"Alerta",0x0 + 0x30)
    }
  }
{% endhighlight %}
    

En conclusión resta programar para que se ejecute según el tiempo que consideremos necesario. Si no saben como hacerlo, hace un tiempo escribí sobre ello: [Ejecutar script de manera programada](http://blog.victorsilva.com.uy/powershell-ejecutar-script-de-manera-programada/).

También podríamos generar una función para simplificar la ejecución:

{% highlight posh %}
function Check-BatteryPercentage {
    if ((Get-WmiObject Win32_Battery).BatteryStatus -ne 1) {
      if ((Get-WmiObject win32_battery).EstimatedChargeRemaining -gt 80) {
        $wshell = New-Object -ComObject Wscript.Shell
        $wshell.Popup("Desconectar de la corriente!",0,"Alerta",0x0 + 0x30)
      }
    } else {
      if ((Get-WmiObject win32_battery).EstimatedChargeRemaining -lt 20) {
        $wshell = New-Object -ComObject Wscript.Shell
        $wshell.Popup("Conectar el equipo!",0,"Alerta",0x0 + 0x30)
      }
    }
  }
{% endhighlight %}

Happy scripting!