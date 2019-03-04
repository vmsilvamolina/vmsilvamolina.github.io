---
title: 'PowerShell: Test-Path o como saber si existe un archivo'
date: 2014-05-12T20:24:54+00:00
author: Victor Silva
layout: single
permalink: /powershell-test-path-o-como-saber-si-existe-un-archivo/
dsq_thread_id:
  - "4473513301"
categories:
  - PowerShell
tags:
  - PowerShell
  - Test-Path
  - Cmdlets
---
A veces cuando estamos armando un script, nos encontramos con la necesidad de validar la existencia de un archivo en un directorio en particular, por ejemplo.

Este simple requisito vamos a resolverlo con el comando **Test-Path**.

Ya sea para buscar un archivo o constatar que realmente se encuentre en ese lugar, este muchacho nos devolverá un _True_ o _False_, dependiendo de si lo encuentra o no.

Vamos a recrear una situación para su correcto uso:

Supongamos que necesito verificar si el archivo .ISO de la evaluación de Lync Server (**_LS-E-8308.0-enUS.iso_**) se encuentra en la carpeta Downloads, ubicada en mi perfil. Por lo que vamos a necesitar escribir las siguientes líneas en nuestra consola:

{% highlight posh %}
# Chequear si se encuentra el archivo
$LyncISO = "C:UsersVictorDownloadsLS-E-8308.0-enUS.iso"
Test-Path $WantFile
{% endhighlight %}


Devolviendo un True (si se encuentra) o un False.

Si le damos un poco mas de rosca al asunto, podemos definir un mensaje en caso de que lo encuentre, de la siguiente manera:

{% highlight posh %}
# Chequear si se encuentra el archivo
$LyncISO = "C:UsersVictorDownloadsLS-E-8308.0-enUS.iso"

$ExisteISO = Test-Path $LyncISO

If ($ExisteISO -eq $True) {
   Write-Host "Existe .ISO de Lync!"
} Else {
   Write-Host "No se encuentra la .ISO"
}
{% endhighlight %}

Happy scripting!