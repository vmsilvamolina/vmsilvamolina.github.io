---
title: 'Crear un post en Jekyll con PowerShell'
date: 2017-11-26T14:04:26+00:00
author: Victor Silva
layout: single
permalink: /post-con-powershell/
categories:
  - PowerShell
tags:
  - Jekyll post
  - Jekyll
  - PowerShell
  - PowerShell function
---

Luego de hacer el cambio de plataforma en mi blog (si no lo sabían hablé de esto [acá]() ), sigo cautivado por los encantos de la simplicidad y la personalización. No voy a decir que con Wordpress no podía hacer cosas... pero acá, en Jekyll, es mucho más simple.

Como para todas las cosas hay que definir las configuraciones y/o especificar parámetros para crear un post, por ejemplo. Si queremos publicar un post, es necesario crear un archivo con extensión *.md* (Markdown). Para ello existe un *modus operandus* que define los nombres de los archivos de la siguiente manera:

> 2017-11-26-enlace-al-post.md

Y contiene información sobre el post dentro de un encabezado como el que adjunto a continuación:

{% highlight markdown %}
---
title: 'Título del post'
date: 2017-11-29T14:04:26+00:00
author: Victor Silva
layout: single
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

### New-JekyllPost

Para optimizar tiempos de edición y escritura vamos a generar una función que nos permita crear el archivo necesario para publicar en Jekyll, generando el contenido que requiere la estructura de modo que con escribir una línea simple de código, ya nos encontremos editando el archivo.

Lo primero que hay que hacer es empezar a definir la función:

{% highlight posh %}
function New-JekyllPost {

}
{% endhighlight %}

