---
title: 'PowerShell - Definiendo mejores funciones!'
date: 2015-03-05T11:58:16+00:00
author: Victor Silva
layout: post
permalink: /powershell-definiendo-mejores-funciones/
dsq_thread_id:
  - "4488313826"
categories:
  - PowerShell
tags:
  - Cmdlets
  - Funciones
  - Funciones avanzadas
  - PowerShell
---
Si bien el tema funciones ya lo tratamos, me gustaría hacer énfasis en la definición de funciones de una manera mas avanzada, desarrollada y estilizada.

Existen muchas maneras de poder definir visualmente una función; utilizando tabulaciones para mantener la estructura visual del texto, definiendo los parámetros ordenados, agregando información de ayuda comentada, etc. A partir de PowerShell v2.0 se introdujo el concepto de funciones avanzadas, lo que permite (a grandes rasgos) definir **Cmdlets** del tipo "
reales"
; o sea, como las funciones que vienen definidas ya en PowerShell. Si bien, no todas las funciones que definamos pueden ser útiles para otros proyectos, nos sirve para mantener más ordenado, con mas información y con más acciones que si definimos funciones de manera tradicional.

## Información de las funciones

Lo primero que vamos a ver es de agregar el siguiente cuerpo al inicio de las funciones:

<img src="https://lh4.googleusercontent.com/-yZrxbP5-VtQ/VPiQZXU0YVI/AAAAAAAAG2s/QemZETit1rE/w386-h167-no/PS_Adv_Function_0.png" width="593" height="219" class="alignnone" />

El bloque de código anterior, define la información adicional de la función. Por ejemplo, si ejecutamos el Get-Help para esta función nos devolverá una estructura de información, como si fuese una función incluida por defecto en PowerShell:

<img src="https://lh6.googleusercontent.com/-OpbOAqXZ9Ko/VPhnvSpQo0I/AAAAAAAAG2E/aCXdlo-Gtg8/w490-h336-no/PS_Adv_Function_1.png" width="490" height="336" class="alignnone" />

A modo de aclaración, se modificaron los valores para que devuelva información "mas real".

Dejamos de lado la parte de la información en sí del Cmdlet, y vamos a pasar a la parte de parámetros.

**Parámetros**

Los parámetros son los valores de entrada que recibe una función. Es decir, los parámetros se usan para pasarle valores a las funciones. Una función trabajará con los parámetros para concretar las acciones definidas.

Para definir los parámetros vamos a hacer lo siguiente:

<img src="https://lh3.googleusercontent.com/-l8klXJt8irU/VPilRoBe9hI/AAAAAAAAG3A/Hv4SvHpHNVA/w457-h317-no/PS_Adv_Function_2.png" width="457" height="317" class="alignnone" />

{% highlight posh %}
Param(
  [string]$ComputerName,
  [string]$FilePath
)
{% endhighlight %}

Agregando el bloque de código anterior, nos permite, a la hora de llamar la función invocar esos parámetros definidos. Cuando definimos los parámetros **$ComputerName** y **$FilePath**, establecemos que el tipo de variable es un _string_, que es lo que indica la imagen con el parámetro _$ComputerName_.

Si bien la manera de presentar los parámetros tipo lista es una manera, no es obligatorio, se puede hacer lineal. Voy a dejar un ejemplo y como se utilizarían los parámetros en una función simple:

{% highlight posh %}
Function Get-Suma {
param(
$Numero1, $Numero2
)

$Resultado = $Numero1 + $Numero2
Write-host $Resultado
}

Get-Suma -Numero1 8 -Numero2 12
{% endhighlight %}

Cuyo resultado es **20**

## Valores predefinidos de los parámetros

En caso de querer forzar valores predefinidos en los parámetros, podemos hacer lo siguiente:

param(
  [parameter(Mandatory=$true)]
  [ValidateSet("Memoria", "CPU")]
  [String[]]$Object, 
  [string]$ChartType, 
  $Values, 
  [string]$FileName
)

Esto permite que a un parámetro que nosotros definamos en una función podamos definir valores conocidos. En el ejemplo tenemos el parámetro $Object, el cual tiene como valores predefinidos **_Memoria_** y **_CPU_**.

Happy scripting!