---
title: Expresiones regulares en PowerShell
date: 2016-07-09T20:03:08+00:00
author: Victor Silva
layout: post
permalink: /expresiones-regulares-en-powershell/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"3307acda8c7f";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:82:"https://medium.com/@vmsilvamolina/expresiones-regulares-en-powershell-3307acda8c7f";}'
dsq_thread_id:
  - "5353506418"
categories:
  - PowerShell
---
Para los que piensan en que situación vamos a depender de usar o no expresiones regulares en PowerShell, los invito a seguir leyendo el post ya que vamos a ver varios prácticos que se resuelven utilizando expresiones regulares. Por más que parezca un tema complejo vamos a ver que a medida que empezamos a utilizarlas el camino es más sencillo.

## Buscar información

Sobre algunos casos es necesario buscar cierta información, la cual cumple ciertos patrones. En PowerShell tenemos el operador **_-match_** que podemos utilizar como muestra el siguiente ejemplo:

En nuestra empresa nombramos nuestros servidores comenzando con SRV y continuando con algunas letras que determinen el rol del servidor y 2 número al final: "
SRVEXCH01"
, puede ser un caso de servidor. Para encontrar nombres de servidores dentro de un texto en particular, vamos a definir el siguiente patrón:

> $pattern = &#8216;SRV[A-Z]{2,4}\d{2}&#8217;

Vamos a desglosar esta expresión para comprender mejor como trabaja:
   
 - **SRV**: Cumple mi primera condición de nomenclatura en donde todos mis servidores comienzan con SRV.
   
 - **[A-Z]{2-4}**: Continuando con mi nomenclatura el nombre del servidor debe contener información del rol que contiene y esta información no debe pasar los 4 caracteres (todos en mayúscula).
   
 - **\d{2}**: Al final del nombre debe contener un número de 2 dígitos.

Ahora que tenemos el patrón vamos a probar diferentes ejemplos de textos que contienen nombres de servidores que cumplen con el patrón y otros no:

{% highlight posh%}
  $text = 'El nombre del controlador de dominio es SRVDC01 y el servidor de DHCP es SRVDHCP03.'
  $pattern = 'SRV[A-Z]{2,4}\d{2}'
  $text -match $pattern
{% endhighlight %}
    

Considerando el código anterior se deja en evidencia el uso del operador _-match_ para comprobar si se encontraban coincidencias con respecto al patrón de búsqueda. Ésta expresión devuelve resultados booleanos ($true o $false). Debido a que el ejemplo que utilizamos devuelve $true, podemos observar el resultado de esa evaluación accediendo a una variable automática llamada **_$matches_**

Donde podemos armar algo más estructurado como lo siguiente:

{% highlight posh%}
  if ($text -match $pattern) { $matches[0] }
{% endhighlight %}
    
## Patrones

Me gustaría compartir algunos ejemplos de patrones según el tipo de búsqueda:

### Multiples caracteres

{% highlight posh%}
  $text = 'Mi nombre es James Bond'
  $pattern = 'Jame[^abc]'
  $text -match $pattern
  #Resultado: $true
{% endhighlight %}
    
El resultado es true, ya que mi patrón excluye las letras _a_, _b_ y _c_ como último caracter (James no termina con ninguna de esas letras).

### Según la posición

{% highlight posh%}
  $text = 'PowerShell es lo peor'
  $text -replace 'peor$','mejor'
  #Resultado: PowerShell es lo mejor
{% endhighlight %}
    
Utilizamos el signo **$** para indicar que valide el patrón si se encuentra al final de la línea.

### Select-String

Pero tenemos un inconveniente, que capaz no lo notaron; el resultado solamente devolvió uno de los dos nombres que coincidían, ya que -match solamente devuelve el primer valor verdadero.

¿Que sucede con los casos en donde necesitamos obtener todos los resultados que cumplen con el expresión? En estos casos vamos a utilizar el cmdlet **_Select-String_**. Para usar el cmdlet anterio debemos asignar el pattern al parámetro **_-AllMatches_** y expandir las propiedades como ejemplifica la siguiente línea:

{% highlight posh%}
  $text | Select-String -AllMatches $pattern | select -ExpandProperty Matches | select -ExpandProperty Value
{% endhighlight %}

Happy scripting!