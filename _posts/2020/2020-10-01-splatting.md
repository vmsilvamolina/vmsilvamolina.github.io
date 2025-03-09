--- 
title: "PowerShell Splatting: ¿qué y por qué?"
author: Victor Silva
date: 2020-10-01T23:59:00+00:00 
layout: post 
permalink: /powershell-splatting/
excerpt: 'PowerShell tiene muchas, pero muchas cosas buenas (hasta diría que excelentes, pero quiero mantener mi subjetividad lo más alejada posible). Cosas que simplifican el día a día, el uso y hasta el formato de las expresiones y estructuras. Y es por esto último que quiero hablar del "Splatting", o cómo hacer que los valores de los parámetros de una función se vean lindos y ordenados.'
categories: 
  - PowerShell
tags: 
  - PowerShell
  - PowerShell 7
  - Splatting
---

PowerShell tiene muchas, pero muchas cosas buenas (hasta diría que excelentes, pero quiero mantener mi subjetividad lo más alejada posible). Cosas que simplifican el día a día, el uso y hasta el formato de las expresiones y estructuras. Y es por esto último que quiero hablar del "Splatting", o cómo hacer que los valores de los parámetros de una función se vean lindos y ordenados.

Según la documentación oficial de PowerShell que ofrece Microsoft en [docs.microsoft.com](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_splatting?view=powershell-7):

> Splatting is a method of passing a collection of parameter values to a command as unit. Windows PowerShell associates each value in the collection with a command parameter.

El formato de los cmdlets en PowerShell hace que el uso sea muy fácil, a pesar de lo que pueda parecer al principio. En la mayoría de los casos, al ingresar un comando junto a los distintos parámetros y valores necesarios, todo puede caber en una línea simple de código que se ajusta adecuadamente en el ancho standard de 80 caracteres que habitualmente se usa en la consola o en los editores de código. Sin embargo, existen ocasiones en las que es necesario especificar muchos parámetros, y algunos de esos valores pueden ser largos, como IDs por ejemplo. 

Vamos a utilizar el comando `New-AzFunctionApp` que nos permite crear una Function App en Azure, tal como comentamos en el post (en inglés) [Azure Functions with PowerShell: Swiss army knife for Ops](https://blog.victorsilva.com.uy/functions-swiss-army-ops/) y que por defecto vamos a tener que pasarle varios comandos con información variada:

{% highlight posh%}
New-AzFunctionApp -Name $FunctionAppName -ResourceGroupName $ResourceGroupName -StorageAccount $storageAccountName -Location $Location -Runtime "PowerShell" -RuntimeVersion "7.0"
{% endhighlight %}

Un ejemplo interesante, ya que tenemos 7 parámetros y sus correspondientes valores. ¿Y cómo sería el formato utilizando Splatting? De la siguiente manera:

{% highlight posh%}
$newFunctionParams = @{
  Name              = $FunctionAppName
  ResourceGroupName = $ResourceGroupName
  StorageAccount    = $storageAccountName
  Location          = $Location
  Runtime           = "PowerShell"
  RuntimeVersion    = "7.0"
}
New-AzFunctionApp @newFunctionParams
{% endhighlight %}

De todas formas, esta no es la única forma de organizar la información.

### Métodos para dar formato

Usar Splatting también es una manera de ordenar visualmente la información y la legibilidad, donde en vez de tener líneas horizontales interminables de información y declaraciones, Splatting ofrece un formato limpio, conciso y de fácil lectura expandiendose verticalmente.

A su vez, Splatting permite dos maneras de dar formato: utilizando *arrays* o *hash tables*. Veamos a continuación como es el formato en cada tipo utilizando el mismo cmdlet par ambos escenarios: `Get-ItemProperty`.

#### Array

En la documentación del cmdlet `Get-ItemProperty` se detalla que los parámetros **Path** y **Name** tienen la posición 0 y 1 respectivamente:

<img src="/assets/images/postsImages/PS_Splatting_0.png" class="alignnone">

Por lo que la sentencia para ejecutar el comando sin dejar explícitos los parámetros (simplemente utilizando "*positional parameters*") tendríamos lo siguiente:

{% highlight posh%}
Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion ProgramFilesDir
{% endhighlight %}

Se puede usar una matriz si los parámetros son posicionales, lo que significa que no es necesario especificar un nombre de parámetro. 

Para la función anterior, usar splatting con un array tendría la siguiente estructura:

{% highlight posh%}
$Params = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion",
"ProgramFilesDir")
Get-ItemProperty @Params
{% endhighlight %}

<div><b>Nota:</b> Prestar atención a que en el llamado de la variable <b>Params</b> se hace uso del <b>@</b> en lugar de <b>$</b>, para que sea tratada como tal dentro de splatting.</div>{: .notice--success}


#### Hash table

El segundo tipo de formato es por medio de hashtables, que permiten declarar los valores de los parámetros como "clave-valor", siendo la forma más utilizada a la hora de recurrir a splatting y una *best pratice*.

Esta manera es la utilizada en el primer ejemplo (usando la función New-AzFunctionApp), por lo que para el ejemplo con la función Get-ItemProperty sería de la siguiente manera:

{% highlight posh%}
$Params = @{
  Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion";
  Name = "ProgramFilesDir";
}
Get-ItemProperty @Params
{% endhighlight %}

Como último comentario destacar que es posible utilizar **;** para finalizar cada key/value de los parámetros o no, es a gusto del consumidor.

Más info: [Microsoft Docs: About Splatting](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_splatting?view=powershell-7)

Happy scripting!