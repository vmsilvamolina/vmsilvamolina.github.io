--- 
title: "¿Tail en PowerShell?"
author: Victor Silva
date: 2020-02-17T23:18:00+00:00 
layout: post 
permalink: /powershell-tail/
excerpt: "¿A quién le gusta leer logs casi 'infinitos'? Creo que es una tarea que en Windows por mucho tiempo resultó bastante tediosa, sin contar que hacerlo desde el bloc de notas le pone un condimento adicional y, más aún, resolviendo el problema en tiempo real"
categories: 
  - PowerShell
tags: 
  - PowerShell 7.0
  - PowerShell
  - Get-Content
  - scripting
---

¿A quién le gusta leer logs casi 'infinitos'? Creo que es una tarea que en Windows por mucho tiempo resultó bastante tediosa, sin contar que hacerlo desde el bloc de notas le pone un condimento adicional y, más aún, resolviendo el problema en tiempo real...

Pero, simpre podemos contar con PowerShell para salir de esas situaciones. Y ésta no es una exepción. Dentro de todos los cmdlets que ofrece PowerShell, existe `Get-Content` que nos va a permitir obtener el contenido de forma muy similiar a como lo haría *tail* en linux.

## Get-Content al rescate

El cmdlet ofrece varios parámetros, pero nos vamos a detener en 3 principalmente:

* **TotalCount**: Especifica el número de líneas desde *el comienzo* del archivo (u otro elemento). Por defecto tiene el valor `-1` (todas las líneas). También cuenta con 2 alias: `First` o `Head`.
* **Tail**: Especifica el número de líneas pero desde *el final*. También tiene el alias `Last`.
* **Wait**: Mantiene el archivo abierto después de que se hayan generado todas las líneas existentes. Mientras espera, Get-Content verifica el archivo una vez por segundo y genera nuevas líneas si están presentes. Puede interrumpir la espera presionando **CTRL + C**. La espera también finaliza si el archivo se elimina, en cuyo caso se informa un error que no termina.

Para generar un log, a usar como escenario para ver el funcionamiento, vamos a usar el siguiente código:

{% highlight posh%}
1..100 | Foreach-Object -Process {
Add-Content -Value $("[Information][{0}] Log important message number {1}" -f $(Get-Date),$PSItem) -Path file.log
Start-Sleep -Milliseconds 1000
}
{% endhighlight %}

Ya generando el "log", vamos a leer el contenido en tiempo real de la siguiente manera:

{% highlight posh%}
Get-Content -Path .\file.log -Wait
{% endhighlight %}

Comparto un GIF para ver mejor el comportamiento:

<img src="/assets/images/postsImages/PS_Tail_1.gif" class="alignnone">

Donde se puede apreciar las líneas que van escribiendose en el log se reflejan en la salida de get-content, mientras que cuando se detiene el nuevo contenido del log, el parámetro wait sigue indicando que el cmdlet siga leyendo cada 1 segundo nuevo contenido en el log.

Para el caso de obtener las primeras líneas de código, por ejemplo: las 5 primeras, podemos usar el parámetro First (alias del parámetro **TotalCount**, que para gusto personal es más difícil de asociar):

{% highlight posh%}
Get-Content -Path .\file.log -First 5
{% endhighlight %}

De forma contraria, si queremos obtener las últimas líneas, usamos **-Tail** (o su alias **Last**):

{% highlight posh%}
Get-Content -Path .\file.log -Tail 5
{% endhighlight %}

<img src="/assets/images/postsImages/PS_Tail_2.png" class="alignnone">

Happy scripting!