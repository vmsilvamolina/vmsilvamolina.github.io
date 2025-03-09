---
title: Analizar logs de IIS con PowerShell
date: 2018-04-12T19:57:00+00:00
author: Victor Silva
layout: post
permalink: /logs-iis-powershell/
excerpt: "Existen numerosas herramientas de análisis de logs para IIS y para logs en general, y probablemente sea una excelente idea utilizar estos sistemas para realizar un monitoreo continuo de nuestras soluciones. Sin embargo, en el mundo real a veces solo tienes un montón de logs de IIS y algunas preguntas simples por responder con la información que allí se aloja."
categories:
  - PowerShell
tags:
  - IIS
  - PowerShell
  - Logs
  - Analizar
  - Expresiones regulares
---

Existen numerosas herramientas de análisis de logs para IIS y para logs en general, y probablemente sea una excelente idea utilizar estos sistemas para realizar un monitoreo continuo de nuestras soluciones. Sin embargo, en el mundo real a veces solo tienes un montón de logs de IIS y algunas preguntas simples por responder con la información que allí se aloja. 

PowerShell viene integrado al Sistema Operativo, por lo que pasa a ser *LA OPCIÓN* predeterminada para este tipo de escenarios.

## Recursos a disposición

El formato de los logs de IIS es **W3C Extended** y, básicamente, la estructura de los logs es la siguiente:

{% highlight plaintext%}
#Software: Microsoft Internet Information Services 6.0
#Version: 1.0
#Date: 2018-03-01 13:04:20 
#Fields: time c-ip cs-method cs-uri-stem sc-status cs-version 
13:04:20 172.16.255.255 GET /default.htm 200 HTTP/1.0  
{% endhighlight %}

Adicional a lo anterior el formato no se encuentra muy alineado con los comandos incorporados de PowerShell, por ejemplo los cmdlets *Import-Csv* o *ConvertFrom-Csv*. Si bien pueden ser utilizados con el parámetro *Delimeter* y algunas manipulaciones de los headers, no es el mejor recurso disponible. Si comenzamos a pensar en manipulación del contenido, lo primero que debemos considerar son las **expresiones regulares**.

Hace un tiempo escribí una entrada en este blog sobre el tema [expresiones regulares en PowerShell](https://blog.victorsilva.com.uy/expresiones-regulares-en-powershell/).

## Código

De lo que se expuso anteriormente, podríamos resolver nuestro problema con el siguiente bloque de código:

{% highlight posh%}
$Path = "C:\Users\vmsilvamolina\Desktop\Logs\IIS-log.log"
$Properties = @{}

Get-Content -Path $Path |
    ForEach-Object {
        if ($_ -match '^#') {
            if ($_ -match '^#(?<Clave>[^:]+):\s*(?<Valor>.*)$') {
                if ($Matches.Clave -eq 'Fields') {
                    $Fields  = @(-split $Matches.Valor)
                }
            }
        } else {
            $FieldValues = @(-split $_)
            $Properties.Clear()
            for ($Index = 0; $Index -lt $FieldValues.Length; $Index++) {
                $Properties[$Fields[$Index]] = $FieldValues[$Index]
            }
            [pscustomobject]$Properties
        }
    }
{% endhighlight %}

Obteniendo la siguiente salida en consola:

<img src="https://bvqurw.ch.files.1drv.com/y4m4MXyWg5p_HFbFrW9WJX-JpCmtoOdbbtKaadwFWav_CrdlE0_qFofkdypMw0D7ea1Ttag6ipv82vzw9sowdH4tC29T0F6fmcWF1U76HP5T_sk_A2aS2N8o_CAiSKBb564G5CayTIlUh774XKs1MliuWZ4A1LE0jafqMxqMDt2CvS2QOs1ohF6h1MnFYpdeqHR9ek_mc1m-0_VtUl_n71BCQ?width=859&height=452&cropmode=none" width="859" height="452" alt="Salida en consola" class="alignnone size-medium" />

### Paso a paso

Ahora vamos a desglosar cada línea para entender mejor que ejecutamos :)

Lo primero, se define una variable donde vamos a definir el archivo a analizar (después vamos a mejorar este mecanismo) junto a un array donde se guardarán los valores del log ya manipulado.

Por medio del cmdlet **Get-Content** obtenemos la información del log y utilizamos **Foreach-Object** para analizar cada línea del archivo.

El primer **if** comprueba si la línea de texto comienza con el caracter <b>#</b> (por medio de una expresión regular muy sencilla): esto se debe a que al momento de comenzar a registrar los eventos y actividades, el sistema agrega líneas de información (sistema utilizado, fecha, formato del log):

{% highlight plaintext%}
#Software: Microsoft Internet Information Services 6.0
#Version: 1.0
#Date: 2018-03-01 13:04:20 
#Fields: time c-ip cs-method cs-uri-stem sc-status cs-version 
13:04:20 172.16.255.255 GET /default.htm 200 HTTP/1.0  
{% endhighlight %}

Y éstas deben ser descartadas... Pero antes debemos considerar un segundo **if** en donde se utiliza una expresión regular un poco más compleja para separar en 2 grupos los valores y así poder filtrar lo que realmente es necesario. La expresión regular en cuestión es la siguiente:

> ^#(?\<Clave\>[^:]+):\s+(?\<Valor\>.+)$

Les comparto un recurso web para realizar comprobaciones de expresiones regulares: [https://regex101.com/](https://regex101.com/). Si tomamos el bloque de texto anterior la comprobación del patrón definido cumple con lo que requerimos:

<img src="https://bvqzrw.ch.files.1drv.com/y4mckebc1OsUdC3DeqwUhAedScnXCK2x6Qc74dZzc_zAFxNXGGGFFbzZkvu-OgTwI_Do7PQQi5WkVokobMzM0cc5c13z5bpIgscX6UGv3RRhQf8VSWws59ULSw8Sd6j-JMhK816XXTNc3cnqf7-xYqjv-BtUVXEonKGXX2SY2-_87DDGxRphoPKYoQ3la274ORu7rN4paEx-hM1mDP3E-_5AQ?width=1096&height=580&cropmode=none" width="1096" height="580" alt="Patrón en regex101.com" class="alignnone size-medium" />

Y en caso que corresponda a una línea con información de actividad en el servidor, la misma es separada por cada propiedad y agregada al objeto custom **[pscustomobject]$Properties**.

## Mejoras

Siempre es posible mejorar código... para ello es posible agrupar el bloque anterior bajo una función, como por ejemplo:

{% highlight posh%}
function ConvertFrom-IISLog {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string[]]
    $Path
  )

  process {
    foreach ($SinglePath in $Path) {
      $Properties = @{}

      Get-Content -Path $SinglePath |
        ForEach-Object {
          if ($_ -match '^#') {
            if ($_ -match '^#(?<Clave>[^:]+):\s*(?<Valor>.*)$') {
              if ($Matches.Clave -eq 'Fields') {
                  $Fields  = @(-split $Matches.Valor)
              }
            }
          } else {
            $FieldValues = @(-split $_)
            $Properties.Clear()
            for ($Index = 0; $Index -lt $FieldValues.Length; $Index++) {
                $Properties[$Fields[$Index]] = $FieldValues[$Index]
            }
            [pscustomobject]$Properties
          }
        }
    }
  }
}
{% endhighlight %}

Y usar la función de la siguiente manera:

{% highlight posh%}
Get-ChildItem C:\inetpub\logs\LogFiles\W3SVC1 | ConvertFrom-IISLog
{% endhighlight %}

Happy scripting!