---
title: 'Crear un post en Jekyll con PowerShell'
date: 2019-11-24T16:04:26+00:00
author: Victor Silva
layout: post
permalink: /post-con-powershell/
excerpt: "Luego de hacer el cambio de plataforma en mi blog, sigo cautivado por los encantos de la simplicidad y la personalización. No voy a decir que con Wordpress no podía hacer cosas... pero acá, en Jekyll, es mucho más simple."
categories:
  - PowerShell
tags:
  - Jekyll post
  - Jekyll
  - PowerShell
  - PowerShell function
---

Luego de hacer el cambio de plataforma en mi blog (si no lo sabían hablé de esto [acá](https://blog.victorsilva.com.uy/cambio-de-look/) ), sigo cautivado por los encantos de la simplicidad y la personalización. No voy a decir que con Wordpress no podía hacer cosas... pero acá, en Jekyll, es mucho más simple.

Como para todas las cosas hay que definir las configuraciones y/o especificar parámetros para crear un post, por ejemplo. Si queremos publicar un post, es necesario crear un archivo con extensión *.md* (Markdown). Para ello existe un *modus operandus* que define los nombres de los archivos de la siguiente manera:

> 2019-11-24-enlace-al-post.md

Y contiene información sobre el post dentro de un encabezado como el que adjunto a continuación:

{% highlight markdown %}
---
title: 'Título del post'
date: 2019-11-24T14:04:26+00:00
author: Victor Silva
layout: post
permalink: /enlace-al-post/
categories:
  - Ejemplo
tags:
  - Jekyll post
  - Markdown
---
{% endhighlight %}

En donde queda bien explícito la definición de la información al respecto, como es el título, la fecha de publicación, sobre que URL se va a publicar, la/s categoría/s a la que pertenece el post y las etiquetas para identificar el contenido.

Ahora bien ¿estamos frente a una situación en la que podemos hacer uso de PowerShell para agilizar nuestra implementación y/o optimizar tiempos? Creo que la respuesta es un sí con mayúsculas, por lo que vamos a pasar a ver como podemos acelerar el proceso...

## New-JekyllPost

Para optimizar tiempos de edición y escritura vamos a generar una función que nos permita crear el archivo necesario para publicar en Jekyll, generando el contenido que requiere la estructura de modo que con escribir una línea simple de código, ya nos encontremos editando el archivo.

Lo primero que hay que hacer es empezar a definir la función:

{% highlight posh %}
function New-JekyllPost {

  }
{% endhighlight %}

Lo segundo es definir los parámetros que vamos a utilizar para desplegar los archivos. Sin duda que los más básicos y necesarios son el título, la fecha de publicación y la categoría (o categorías) a la que pertenece el artículo.

Ya que la mayoría de las veces escribimos y publicamos el post sobre el mismo día, por lo que podemos definir el parámetro *$Date = (get-Date)*, en donde al momento de invocar la función, si obviamos definir el valor del parámetro **$Date** automáticamente nos ingresa la fecha corriente:

{% highlight posh %}
function New-JekyllPost {
    [CmdletBinding()]
    param ( 
      [Parameter(Position=0, ValueFromPipeline=$true)][PSObject[]]$Date = (Get-Date),
      [Parameter(Position=1, ValueFromPipeline=$true)][string]$Title,
      [Parameter(Position=2, ValueFromPipeline=$true)][string]$Category
    )
  }
{% endhighlight %}

Ya con los parámetros podemos comenzar a trabajar sobre el cuerpo de la función procesando primero la fecha, debido a que el formato por defecto es:

> Sunday, November 24, 2019 12:38:54 PM

Definimos las siguientes variables ya manipuladas:

{% highlight posh %}
if ($Date.GetType() -eq [string]) {
    $Date = [datetime]$Date
  }
  $DatePost = $Date | Get-Date -Format s
  $DatePostName = ($DatePost).Split("T")[0]
{% endhighlight %}

Luego viene el formato del nombre del archivo con extensión *.md* y del formato de la URL. Para ello pasamos el valor ingresado en el parámetro todo a minúscula con el método *.ToLower()*. También es requerido separar las palabras con guiones, ya que en las URL no se permiten espacios vacíos. Luego de tener eso formateado, generamos el archivo en cuestión:

{% highlight posh %}
$TitlePost = $Title.Replace(" ","-").ToLower()
  $PostName = [string]$DatePostName + "-" + $TitlePost + ".md"
  New-Item -Path $PostPath -ItemType File -Name $PostName | Out-Null
  [string]$PostFileName = $PostPath + "\" + $PostName
{% endhighlight %}

Hasta acá, ya podríamos comenzar a editar el archivo para luego publicarlo. Pero podemos avanzar un poco más... vamos a agregarle el encabezado del que hablamos, utilizando las variables que definimos anteriormente:

{% highlight posh %}
$Values = @"
  ---
  title: $Title
  date: $DatePost
  author: Victor Silva
  layout: post
  permalink: /$TitlePost/
  categories:
    - $Category
  ---
  "@
  Add-Content -Path $PostFileName -Value $Values
{% endhighlight %}

Y ahora sí, juntando todas las partes, obtendremos la función que nos va a permitir crear posts para Jekyll usando PowerShell:

{% highlight posh %}
function New-JekyllPost {
    [CmdletBinding()]
    param ( 
      [Parameter(Position=0, ValueFromPipeline=$true)][PSObject[]]$Date = (Get-Date),
      [Parameter(Position=1, ValueFromPipeline=$true)][string]$Title,
      [Parameter(Position=2, ValueFromPipeline=$true)][string]$Category
    )
    Process {
      $PostPath = "C:\users\vmsilvamolina\OneDrive\Documentos\GitHub\vmsilvamolina.github.io\_posts\"

      if ($Date.GetType() -eq [string]) {
        $Date = [datetime]$Date
      }
      $DatePost = $Date | Get-Date -Format s
      $DatePostName = ($DatePost).Split("T")[0]

      $TitlePost = $Title.Replace(" ","-").ToLower()
      $PostName = [string]$DatePostName + "-" + $TitlePost + ".md"
      New-Item -Path $PostPath -ItemType File -Name $PostName | Out-Null
      [string]$PostFileName = $PostPath + "\" + $PostName

      $Values = @"
  ---
  title: $Title
  date: $DatePost
  author: Victor Silva
  layout: post
  permalink: /$TitlePost/
  categories:
    - $Category
  ---
  "@
      Add-Content -Path $PostFileName -Value $Values
    }
  }
{% endhighlight %}

Happy scripting!