---
title: Pester framework
date: 2016-08-05T19:26:47+00:00
author: Victor Silva
layout: post
permalink: /pester-framework/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"c3225be4e1a1";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:63:"https://medium.com/@vmsilvamolina/pester-framework-c3225be4e1a1";}'
dsq_thread_id:
  - "5403838337"
categories:
  - PowerShell
tags:
  - BDD
  - Pester
  - PowerShell
  - Test
  - Unitt Testing
---
Hace bastante tiempo que estoy por escribir sobre Pester. Si bien es un tema que ya conocía, todavía no había puesto en marcha su uso para mis scripts. Es por eso que decidí ponerme al día con este tema. Aquí les comparto una pequeña guía sobre los fundamentos de Pester y que podemos llegar a hacer con este framework.

## Que es Pester?

Pester es un _unit testing framework_ para PowerShell. Básicamente, **unit testing** (pruebas unitarias) es una forma de comprobar el correcto funcionamiento de un módulo de código de forma aislada.

Lo que nos permite este framework es poder mejorar la calidad de nuestros scripts a la vez que nos genera mayor tranquilidad a la hora de comprobar la funcionalidad de nuestros scripts.

## Cómo empezar?

Suponiendo que la versión de PowerShell en nuestro sistema es 5.0 o superior, les comento que contamos con todo lo necesario para comenzar a trabajar!

Ahora bien, si ese no es nuestro caso, vamos a tener que realizar alguno de los siguientes caminos:

La opción más accesible y fácil de poder acceder a Pester es usar el Package Management desde la consola con permisos elevados:

{% highlight posh %}
Find-Module “Pester” | install-module
{% endhighlight %}

La segunda opción es descargar el zip desde la página de Github del proyecto: [enlace](https://github.com/pester/Pester). Luego de la descarga, extraer los archivos dentro de la carpeta de módulos que utilizamos usualmente (_&#8216;C:\Program Files\WindowsPowerShell\Modules&#8217;_).

Como última opción es realizar un fork del proyecto en Github, en donde puede resultar un poco confuso si no se tiene experiencia, pero es la mejor manera de poder colaborar con el proyecto.

## Estructura

Para comenzar vamos a escribir nuestro primer test. Y qué es un test? un test no es más que un script (o función) en PowerShell. Por convención (no es obligatorio) se utiliza la siguiente estructura:

> ScriptName.Tests.ps1

Un ejemplo: si nuestro script se llama **_Get-SystemInfo.ps1_** de acuerdo con lo que se comentó anteriormente nuestro test de pester se llamará **_Get-SystemInfo.Tests.ps1_**.

Existe un cmdlet llamado New-Fixture que pertenece al módulo de pester que permite crear un script vacío junto con el test correspondiente (en blanco también) de la siguiente manera:

{% highlight posh %}
#Invocamos el cmdlet para crear nuestros archivos
New-Fixture -Path .\ -Name PesterExample
{% endhighlight %}

<img src="https://qf5y0w-ch3302.files.1drv.com/y4m6-bbhOTmRmIw1i_rwNwiNr3MUGTYIqGN_0YAkWB7vkexGSbHXTFlCfT4CIC779vMYiBIxJ1DtCT1UlnAzU793ddCerlgBafvYAeDtO0PGOxtLU82fA1Zs2d9jiFCsZqQdJKDl5Am02aYeL8phEA1nbQKefJSekf2J-lLFQ5H0npSR0rbkHnl6orCU0rdgykkdqD9eWytdo_2NF5ptqArBw?width=859&#038;height=239&#038;cropmode=none" width="859" height="239" alt="New-Fixture (Pester)" class="alignnone size-medium" />

## Hola Mundo!

Como comentario me gustaría compartir que si bien la función **New-Fixture** ayuda a crear nuestro script y test, no es del todo útil ya que el archivo del test contiene una estructura que nos es la más adecuada en la mayoría de los casos en el mundo real.

Vamos a ver como luce el archivo **_PesterExample.Tests.ps1_**:

<img src="https://av920w-ch3302.files.1drv.com/y4m5uHy73liaP8wTlTXIA_l90no8k67R2MZAD_wcyTAn26bvZ8fjJe_BXjeLeijbqfLFaLQN9Jt0RGb5EDjU79njFy1TVuZ9U3wW1JExg3RgOpK8Cnaox6lkxiLyt_ddU_4m1I8adLCyx6TgOmH-5UT42ZBjFfIpjvBlQPM55ao8fluFRbitnyW7X9vcdBMI3NtPIKOiop_8Vb6k4xWTxv2yw?width=659&#038;height=180&#038;cropmode=none" width="659" height="180" alt="Pester test" class="alignnone size-medium" />

En primer lugar tenemos la estructura **_Describe_** que básicamente separa los tests dentro de nuestro script (similar a lo que hace una región, por decirlo de alguna manera). Luego tenemos el bloque **_It_** que no es más que el test en sí. Por último se presenta el mecanismo **_Should_** donde la expresión va a ser evaluada obteniendo un precioso mensaje verde en consola si todo va bien, o en su defecto de color rojo.

Toca modificar el script de la función para hacer un ejemplo simple, de la siguiente manera:

{% highlight posh %}
#PesterExample.ps1
function PesterExample($value) {
    return $value
}
{% endhighlight %}
    

Un función muy muy simple que solo retorna el valor ingresado.

Ahora con nuestro "
script"
, vamos a modificar nuestro test, de la siguiente manera:

{% highlight posh %}
#PesterExample.Tests.ps1
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "PesterExample" {
    It "Print text correctly" {
        PesterExample 2 | Should Be 2
    }
}
{% endhighlight %}

Si prestan atención verán que el string de la estructura _It_ fué modificado para que imprima información relacionada con las pruebas que queremos realizar; como nuestra función imprime texto, es relevante que la prueba indique si cumple el objetivo o no. Como segundo dato se modificó la expresión **Should Be** en donde se invoca la función **_PesterExample_** con un valor definido y el resultado esperado.

Para ejecutar el test, basta con ejecutar el archivo _PesterExample.Tests.ps1_ o pulsar la tecla **F5** si estamos en el ISE. Así se vería el resultado de ejutar lo anterior:

<img src="https://av910w-ch3302.files.1drv.com/y4mzUBbo1ZWH1EgVPsG7_PRmxJJ_A_wDDAQnlABtMDbaNuNr_Wlm7yBcoZoKWrKRZ6WubMY3pq0BqHw2KN6fQ-vUBK29ySKocEVcGcetWK05Jl6ep6KwvIUD8R_8qBPlLJMjwP4YD9LQ3sdousHtIZUv9N2_XaTeG-4xNO_OJYYCrhnc-4bVXkAo4ibZzmnFy_zODWQM3HhOpDP1-2ZI1rYsA?width=447&#038;height=99&#038;cropmode=none" width="447" height="99" alt="Resultado del test" class="alignnone size-medium" />

En próximas entregas vamos a ver diferentes secciones que son utilizadas en Pester y ejemplos más complejos.

Happy scripting!