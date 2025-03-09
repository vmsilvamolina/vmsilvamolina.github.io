---
title: 'PowerShell - Cuadros de diálogo en Windows Forms'
date: 2014-09-27T20:23:43+00:00
author: Victor Silva
layout: post
permalink: /powershell-cuadros-de-dialogo-en-windows-forms/
dsq_thread_id:
  - "4480207448"
categories:
  - PowerShell
tags:
  - Cmdlets
  - Cuadro de dialogo
  - PowerShell
  - Windows Forms
---
Para los que les gusta crear una interfaz visual a nuestros scripts (Windows Forms), les voy a compartir una pequeña función que permite crear esos mensajes de advertencia, o de error, o simplemente de información para que nuestros programas queden mas lindos y tengan otros aportes visuales a la hora de interactuar con el usuario que los ejecuta.

La función que hace esta maravilla es la siguiente:

{% highlight posh %}
Function Mostrar-MensajeCuadroDialogo {
  Param (
    [string]$Mensaje, 
    [string]$Titulo, 
    [System.Windows.Forms.MessageBoxButtons]$Botones, 
    [System.Windows.Forms.MessageBoxIcon]$Icono
  )
  return [System.Windows.Forms.MessageBox]::Show($Mensaje, $Titulo, $Botones, $Icono)
}
{% endhighlight %}

Ok, tenemos la función vamos a ver algunos ejemplos y como se van a ver.

Primero vamos a crear un mensaje de información, por ejemplo con el mensaje: "Ha finalizado correctamente el proceso." Necesitamos ejecutar:

{% highlight posh %}
Mostrar-MensajeCuadroDialogo -Mensaje "Ha finalizado correctamente el proceso" -Titulo "Información" -Botones OK -Icono Information
{% endhighlight %}

El resultado del código anterior es la siguiente imagen:

<img class="alignnone" src="https://lh6.googleusercontent.com/-icp2VmXGx7w/VCdGNOYGE2I/AAAAAAAAF3o/J-XZ-3v9Hbc/w326-h172-no/PS_Message_Info.png" alt="" width="326" height="172" />

En cambio, si queremos, por ejemplo, desplegar un mensaje de error, podemos utilizar:

{% highlight posh %}
Mostrar-MensajeCuadroDialogo -Mensaje "Se ha encontrado un error. Vuelva a ejecutar el proceso" -Titulo "Error" -Botones OK -Icono Error
{% endhighlight %}

Y nos aparecerá el siguiente cuadro:

<img class="alignnone" src="https://lh4.googleusercontent.com/-kCzE66ftR8M/VCdGNEFRMMI/AAAAAAAAF3w/bPlueKA4NSQ/w408-h172-no/PS_Message_Error.png" alt="" width="408" height="172" />

Así podremos probar varias combinaciones y diferentes botones a desplegar.

Happy scripting!