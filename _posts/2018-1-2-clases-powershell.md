---
title: Clases en PowerShell
date: 2018-1-2T19:30:46
author: Victor Silva
layout: single
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

### Por qué usar clases?

En repetidas ocasiones nos encontramos escribiendo módulos y funciones por ahí tratando de automatizar el mundo que nos rodea. Es ahí uno de los grandes usos de las clases en PowerShell. Con las clases vamos a poder representar estructuras de datos complejas y más aún al utilizar múltiples funciones que necesitan pasar los mismos datos.

El otro gran punto para usar clases es al momento de trabajar con DSC. Ya en el blog hemos tenido varias entradas hablando sobre DSC ([aquí](https://blog.victorsilva.com.uy/desired-state-configuration/) y [aquí](https://blog.victorsilva.com.uy/powershell-dsc-linux/)). DSC está ganando más y más tracción todos los días y con esta adpoción, hay una brecha aún mayor para los nuevos recursos. Los recursos *DSC Class-based* son simplemente más fáciles de desarrollar y mantener.


### Creando nuestra primer clase

Para definir una clase es necesario utilizar la keyword ***class***:

{% highlight posh %}
class Alien {

}
{% endhighlight %}

Como mencionamos anteriormente, ahora que tenemos nuestra clase definida, podemos crear instancias de ella. Tenemos a disposición varias maneras diferentes de hacer esto. La primera es usar *New-Object* con el parámetro *-TypeName*.

{% highlight posh %}
$greenMan = New-Object -TypeName Alien
{% endhighlight %}

La segunda manera de instanciar una clase es llamar al constructor estático de la clase. Por más información sobre constructores y los tipos existentes acceder al siguiente [enlace](https://en.wikipedia.org/wiki/Constructor_(object-oriented_programming)). Para invocarlo es necesario utilizar los dos puntos de la siguiente manera:

{% highlight posh %}
$greenMan = [Alien]::New()
{% endhighlight %}

### Describiendo las clases

