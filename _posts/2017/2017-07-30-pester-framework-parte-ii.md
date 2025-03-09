---
title: Pester Framework parte II
date: 2017-07-30T10:41:40+00:00
author: Victor Silva
layout: post
permalink: /pester-framework-parte-ii/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:11:"8bb98f52800";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:71:"https://medium.com/@vmsilvamolina/pester-framework-parte-ii-8bb98f52800";}'
dsq_thread_id:
  - "6148369210"
categories:
  - PowerShell
tags:
  - Pester
  - Pester Framework
  - Pester Framework avanzado
  - Pester keywords
---

En esta oportunidad vamos a profundizar sobre los conceptos que se presentaron en el post anterior sobre [Pester](http://blog.victorsilva.com.uy/pester-framework/). Luego de ver de forma introductoria lo que es Pester, vamos a detallar conceptos más avanzados para profundizar el conocimiento sobre este framework.

Pester permite utilizar un montón de palabras clave, pero no todas son necesarias para dominar este framework. Realmente solo hay unas pocas que se necesitan (y se utilizan diariamente) dentro del mundo Pester. Al final, las palabras clave más utilizadas de powershell pester son las siguientes:

<img src="https://ce2vww-ch3302.files.1drv.com/y4m1-I89Iz1GCTT8PXWoEZzbwheFsN9xfWwz0cNk-2htFl5bemtpsjSEGVcUfMDOQHBfb5sTX-4AF8fb9YHvtPdOaVqmoImS65V4xVkb4YN9T3-9CegxmNGtO-N55o9mVNdnQxPfia2Y4j4x4Bph6Cm-VF56SPzf-WAUa6xXaSl3PVJyRPPQchyt1U8ACK909b_tJCOeKP5F-883fsWOBCk1w?width=884&#038;height=315&#038;cropmode=none" width="884" height="315" alt="Pester keywords" class="alignnone size-full" />

Éstas no son las únicas palabras que podemos utilizar en Pester, pero si las más usadas. Dependiendo del código que estemos dispuestos a probar, tendremos que usar algunas otras palabras clave adicionales, pero probablemente serán un reemplazo para la palabra clave &#8216;be&#8217;.

En la imagen anterior, la estructura de palabras clave es "jerárquica" simplemente porque estas palabras clave son en realidad bloques de secuencias de comandos, y deben estar ubicadas una dentro de la otra. Vemos que un _PowerShell Pester script_ comienza con un bloque **_Describe_**, y que todo está ubicado en ese bloque de descripción.

## Una función para la demostración

Para entender mejor las estructura de palabras clave y como se deben utilizar, primero vamos a compartir primero un script, que contiene una función en particular:

{% highlight posh %}
function Get-Pizza {
    [cmdletbinding()]
    Param(
        [ValidateNotNullOrEmpty ()]
        [parameter(Mandatory=$false,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)] 
        [string[]]$Toppings= "Muzzarella"
    )
    begin {
        $Objects = @()
    }
    process {
        Foreach ($Topping in $Toppings) {
            Write-Verbose "Pizza: adding $Topping"
            $Properties = @{}
            $Properties.Add("PizzaTopping",$Topping)

            $Object = New-object -TypeName psobject -Property $Properties
            $Objects += $Object
        }
    }
    end {
        return $Objects
    }
}
{% endhighlight %}
    

La función anterior simplemente genera un objeto con el "
sabor"
 de nuestra pizza (el sabor es la propiedad PizzaTopping).

## Script de Pester

Ahora que tenemos un script, vamos a generar el test para comprobar que funcione correctamente en Pester! Primero voy a compartir el test para luego ir desglosando las **keyword** utilizadas:

{% highlight posh %}
Describe 'Testing the Get-Pizza function' {
    Context 'Testing Input validation' {
        $ToppingsArray = @('Mozzarella';'Pepperoni')
        $SingleTopping = 'Ham'
        it 'Should run when no parameter is provided'{
            $Pizza = Get-Pizza
            $Pizza | should not beNullOrEmpty
        }
        it 'Should Accept PipeLine input'{
            $Pizza = $ToppingsArray | Get-Pizza
            $Pizza | should not beNullOrEmpty
            $Pizza[0].PizzaTopping | should be 'Mozzarella'
            $Pizza.count -gt 1 | should be $true
        }
        it 'Should not accept null values'{
            {Get-Pizza -Size ''} | should throw
        }
        it 'Should Accept Array of toppings'{
            $Pizza = Get-Pizza -Toppings $ToppingsArray
            $Pizza | should not beNullOrEmpty
            $Pizza.count -gt 1 | should be $true
        }
    }
    Context 'Testing returned object contents' {
        $ToppingsArray = @('Pineapple';'Anchovies')
        $SingleTopping = 'Parmesan'
        $Pizza = Get-Pizza -Toppings $SingleTopping
        it 'Should Have a Topping' {
            $Pizza.PizzaTopping | should be 'Parmesan'
        }
    }
}
{% endhighlight %}
    

Antes de continuar, comparto el resultado de ejecutar los dos fragmentos de código anterior. La salida en consola sería la siguiente:

<img src="https://ce2rww-ch3302.files.1drv.com/y4mAGw56hoTt4O_2tF6tfg_ZqUObLerVy7GtLhxXFLTN02FISW1dkzCzVPIbzmX6m2l9mz3mygVpcH-nUmm7kJftg5reIeKrORX4IY2wlg6OjEvYRd0HDl7hFPSON2setIRHo7__yUZBHjBWxTLi4MQeGYzaAKv0N42--UUugqRoTiptvpWy8r-H8g-W2Lg2jkjYV3cKyIGJT62VdscIjUtLg?width=412&#038;height=153&#038;cropmode=none" width="412" height="153" alt="Resultado del test" class="alignnone size-full" />

La otra opción de ejecutar el test (que sería la más correcta, por cierto) es utilizar el cmdlet **Invoke-Pester** (si no recuerdan cual es el procedimiento, les recomiendo revisar el [post anterior](http://blog.victorsilva.com.uy/pester-framework/)).

Ya definido nuestro escenario, vamos a continuar detallando cada palabra y su uso dentro de Pester.

### Describe

La palabra _Describe_ es la más alta en la jerarquía y funciona de forma similar a las regiones que utilizamos normalmente en PowerShell: separar los bloques de código. En este contexto, sirve para identificar los pilares de nuestros test.

### Context

_Context_ como indica su palabra, permite definir contextos de posibles escenarios. En nuestro caso, utilizamos el bloque _Context_ para que englobe todos nuestros tests que pondrán a prueba las diversas entradas posibles que nuestro script puede tener.

### It

El bloque _It_ es el corazón de los PowerShell Pester tests. Contiene el elemento preciso que se está probando. El bloque _It_ contiene uno de los **assertion operators** que mostraremos en las siguientes líneas. El más utilizado es el operador Should.

Aquí un ejemplo de un bloque _It_:

{% highlight posh %}
It 'Should run when no parameter is provided'{
    $Pizza = Get-Pizza
    $Pizza | should not beNullOrEmpty
}
{% endhighlight %}
    

La primera línea es nuestra función principal Get-Pizza (que a la función que realmente queremos hacerle testing) e ingresamos los datos en la variable $Pizza.

Entonces canalizamos el contenido de esa variable al operador _should_, y especificamos que no debería ser nulo o vacío usando los operadores: _not BeNullOrEmpty_.

Si se cumple la condición, la prueba se mostrará en verde en la consola (comprobando de esa manera que la función hace lo que se supone que debe hacer). Si la prueba no se cumple, se mostrará en rojo, obviamente.

### Should

Ya tuvimos una introducción poco formal de _Should_, pero vamos a destacar nuevamente que esta keyword pertenece al bloque _It_ y ejemplificaremos con un par de ejemplos:

{% highlight posh %}
It 'Should Accept Array of toppings'{
    $Pizza = Get-Pizza -Toppings $ToppingsArray
    $Pizza | should not beNullOrEmpty
    $Pizza.count -gt 1 | should be $true
}
{% endhighlight %}
    
El ejemplo anterior se extrajo del test que definimos anteriormente y tiene varias sentencias con *Should*, aunque vamos a centrarnos en la última: 

{% highlight posh %}
$Pizza.count -gt 1 | should be $true
{% endhighlight %}

Ésta sentencia define que la prueba será correcta en el caso que retorne un valor mayor a uno en la cuenta de los objetos resultantes de la función.

Ahora que avanzamos en este framework es momento de comenzar a armar tests más complejos y esperar a la siguiente entrega sobre Pester Framework!

Happy scripting!