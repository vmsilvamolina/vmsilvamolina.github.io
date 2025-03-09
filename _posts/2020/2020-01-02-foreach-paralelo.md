--- 
title: "ForEach-Object en paralelo con PowerShell 7.0"
author: Victor Silva
date: 2020-01-02T13:27:00+00:00 
layout: post 
permalink: /foreach-paralelo/
excerpt: "Los 'loops' o bucles, son pilares fundamentales en los lenguajes de programación/scripting en donde se utilizan ampliamente debido al componente lógico crucial permitiendo iterar a través de una colección de objetos." 
categories: 
  - PowerShell
tags: 
  - PowerShell 7.0
  - PowerShell
  - Loops
  - Foreach paralelo
---

Los "loops" o bucles, son pilares fundamentales en los lenguajes de programación, y/o scripting, en donde se utilizan ampliamente debido al componente lógico crucial permitiendo iterar a través de una colección de objetos.

PowerShell contiene el cmdlet Foreach-Object que permite realizar bucles de forma simple y directa. Su defecto: es secuencial, ya que el siguiente valor en el ciclo solo se procesa después de que el anterior haya finalizado. Pero llegó PowerShell 7.0...

Y cambió las reglas del juego. Introducido en la la versión 7.0 Beta 3, la nueva característica de Foreach-Object -Parallel permite realizar en forma simultánea operaciones utilizando de forma nativa la función del lenguaje Foreach-Object, ampliamente utilizada en nuestros scripts.

La opción **Parallel** en el cmdlet `ForEach-Object` habilita la ejecución de un bucle **ForEach-Object** contra varios valores al mismo tiempo. Con una refactorización mínima, es posible agregar esta nueva funcionalidad a los bucles `ForEach-Object` existentes y obtener un aumento significante de velocidad en las ejecuciones.

## foreach vs ForEach-Object

Aunque el título parece un juego de palabras, es necesario aclarar las disimilitudes entre ambos usos y cuando en realidad hace la diferencia cada forma. Si bien algunas veces consideramos que usar **ForEach** significa estar usando `ForEach-Object` como un "alias", depende efectivamente en que momento se declara y ejecuta, ya que podemos caer en la ejecución de un **PowerShell statement** en vez de ejecutar el cmdlet que trabaja correctamente recibiendo datos desde un pipeline.

## ForEach-Object antes

Tal como se mencionó en el párrafo anterior, `ForEach-Object` está diseñado para iterar a través de objetos en un pipeline. Para demostrar esto, se define un loop sobre una colección de 10 objetos y su impresión en la consola, y midamos cuánto tiempo lleva.

{% highlight posh%}
(Measure-Command {
  1..10 | ForEach-Object {
    Start-Sleep -Seconds 1
    Write-Host $_ -ForegroundColor Yellow
  }
}).TotalMilliseconds
{% endhighlight %}

<img src="/assets/images/postsImages/PS_7_Parallel_0.png" class="alignnone">

## ForEach-Object reloaded

¿Cómo se comportaría el mismo código utilizando ejecuciones en paralelo?

{% highlight posh%}
(Measure-Command {
  1..10 | ForEach-Object -Parallel {
    Start-Sleep -Seconds 1
    Write-Host $_ -ForegroundColor Yellow
  }
}).TotalMilliseconds
{% endhighlight %}

<img src="/assets/images/postsImages/PS_7_Parallel_1.png" class="alignnone">

Lo que anteriormente tomó unos 10 segundos, ahora se ejecutó en menos de 3 segundos. Un dato importante a resaltar es el orden de los objetos devueltos: ya no fue ejecutado secuencialmente. Esto se debe a que está ejecutando varias operaciones a la vez y las devuelve tan pronto como se realiza. De forma predeterminada ejecuta 5 operaciones simultáneas.

Para cambiar el número predeterminado de ejecuciones "paralelas" hay que recurrir al parámetro `ThrottleLimit`. 

No siempre es posible utilizar esta feature, ya que algunos escenarios requerirán que la ejecución sea secuencial, por ejemplo en la transferencia de archivos: ejecuciones en paralelo pueden saturar la conexión o disminuir la velocidad .

Info adicional en el siguiente enlace: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/foreach-object?view=powershell-7

Happy scripting!