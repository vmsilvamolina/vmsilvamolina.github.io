---
title: Clases en PowerShell
date: 2018-01-02T19:30:46
author: Victor Silva
layout: post
permalink: /clases-powershell/
categories:
  - PowerShell
tags:
  - Clases
  - PowerShell
  - PowerShell v5.0
---

En programación orientada a objetos, aunque suene un redundante, se utilizan objetos. Y estos objetos se pueden agrupar en las llamadas clases. Las clases dan forma a un objeto, como si fuese un template, definiendo como debe verse un objeto y potencialmente lo que se necesita para crear uno nuevo.

Es recomendable tener en cuenta la siguiente afirmación:

>Un objeto no es una clase, ni una clase es un objeto. Un objeto es una instancia de una clase.

## Por qué usar clases?

En repetidas ocasiones nos encontramos escribiendo módulos y funciones por ahí tratando de automatizar el mundo que nos rodea. Es ahí uno de los grandes usos de las clases en PowerShell. Con las clases vamos a poder representar estructuras de datos complejas y más aún al utilizar múltiples funciones que necesitan pasar los mismos datos.

El otro gran punto para usar clases es al momento de trabajar con DSC. Ya en el blog hemos tenido varias entradas hablando sobre DSC ([aquí](https://blog.victorsilva.com.uy/desired-state-configuration/) y [aquí](https://blog.victorsilva.com.uy/powershell-dsc-linux/)). DSC está ganando más y más tracción todos los días y con esta adpoción, hay una brecha aún mayor para los nuevos recursos. Los recursos *DSC Class-based* son simplemente más fáciles de desarrollar y mantener.


## Creando nuestra primer clase

Para definir una clase es necesario utilizar la keyword ***class***:

{% highlight posh %}
class Alien {

  }
{% endhighlight %}

Como mencionamos anteriormente, ahora que tenemos nuestra clase definida, podemos crear instancias de ella. Tenemos a disposición varias maneras diferentes de hacer esto. La primera es usar *New-Object* con el parámetro _-TypeName_.

{% highlight posh %}
$greenMan = New-Object -TypeName Alien
{% endhighlight %}

La segunda manera de instanciar una clase es llamar al constructor estático de la clase. Por más información sobre constructores y los tipos existentes acceder al siguiente [enlace](https://en.wikipedia.org/wiki/Constructor_(object-oriented_programming)). Para invocarlo es necesario utilizar los dos puntos de la siguiente manera:

{% highlight posh %}
$greenMan = [Alien]::New()
{% endhighlight %}

## Describiendo las clases

### Propiedades

Las propiedades son cosas sobre un objeto, cosas que lo representan y definen. Si describiéramos un alien como el ejemplo, las propiedades podrían ser altura y peso. Agregamos propiedades a una clase agregando variables dentro de la clase. Si bien no es obligatorio, es una buena idea definir el tipo de variable para determinar el tipo de dato a ingresar:

{% highlight posh %}
class Alien {
    [string]$Nombre
    
    [int]$Altura

    [int]$Peso
  }
{% endhighlight %}

### Validación de las propiedades

Como indica el título, PowerShell permite la validación de las propiedades. Esto permite que los datos que se ingresan cumplan con lo que se requiere para cada propiedad:

{% highlight posh %}
class Alien {
    [ValidatePattern('^[a-z]')][ValidateLength(3,15)][string]$Nombre
    
    [ValidateRange(0,200)][int]$Altura

    [ValidateRange(0,300)][int]$Peso
  }
{% endhighlight %}

### Propiedades ocultas

Las clases de PowerShell también admiten propiedades ocultas. Para ocultar una propiedad, se debe usar la keyword *hidden* justo antes del nombre de la propiedad. Para el siguiente ejemplo vamos a ocultar la propiedad ID sea del tipo GUID y esté oculta para el usuario.

{% highlight posh %}
class Alien {
    [Guid]hidden $ID

    [ValidatePattern('^[a-z]')][ValidateLength(3,15)][string]$Nombre
    
    [ValidateRange(0,200)][int]$Altura

    [ValidateRange(0,300)][int]$Peso
  }
{% endhighlight %}

Y para comprobar esto vamos a ejecutar el código que genera la clase, junto una instancia de la misma llamada $greenMan:

<img src="https://pbpy0w.ch.files.1drv.com/y4ma1uWSE_pLhFfQ7KO40I-jEAourdIH-UwQvSeHUtT5GNmvWvJZa0COe93rCKJLKhxP2BNuWhxG56WNWWlKbHntd97rkjr17-5Uh-mUUD2CsuD_WzDeFZEi3awmhFb-xVKfwMl7LMfbEY7KPCX4ZtCL3_ODpM_nBJvCpZboF1ONKggiWZlbAOziwZCc1bTaONkqYafm5Z_cA6P-S6aAwPfnQ?width=557&height=459&cropmode=none" width="557" height="459" alt="Generar una instancia de la clase 'Alien'" class="alignnone size-full" />

En donde se utilizó:

{% highlight posh %}
$greenMan | Get-Member -MemberType Properties
{% endhighlight %}

Para ver las propiedades disponibles dentro del objeto generado.

Happy scripting!