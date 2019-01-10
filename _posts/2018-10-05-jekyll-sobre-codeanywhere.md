---
title: "Ejecutar Jekyll sobre Codeanywhere"
author: Victor Silva
date: 2018-10-05T21:47:00+00:00
layout: single
permalink: /jekyll-sobre-codeanywhere/
excerpt: ""
categories:
  - Develpment
tags:
  - Ruby
  - Jekyll
  - Containers
  - Codeanywhere
  - Development
  - Desarrollo
  - Draft
---

Hace un tiempo que estoy intentando librarme de ambientes locales a la hora de escribir en el blog porque, si bien me encanta Jekyll como generador de contenido estático, tiene un requisito que es el siguiente: Para poder ver los cambios y/o borradores es necesario ejecutar el blog.

Es decir que se necesita de un **localhost** donde poner en marcha el blog, lo que va en contra de mi movimiento de libertad (en terminos de requerimientos locales).

Es acá donde hablo de mi gran descubrimiento llamado **Codeanywhere** ([https://codeanywhere.com](https://codeanywhere.com)).
En pocas palabras, Codeanywhere es un entorno de desarrollo 100% online, donde se ofrece una solución para poder contar con un IDE completamente accesible desde el browser.

### Repositorio de código

En mi caso, el blog se encuentra alojado en GitHub, por lo que necesitamos hacer un `git clone` de mi repositorio para contar con el código y toda la información del mismo:

{% highlight bash%}
  it clone https://github.com/vmsilvamolina/vmsilvamolina.github.io
{% endhighlight %}

### Instalar Jekyll

Jekyll está desarrollado mayormente en Ruby, por lo que es necesario instalar las gemas necesarias para poder utilizar este generador de contenido:

{% highlight bash%}
  gem install jekyll --no-ri --no-rdoc
{% endhighlight %}

Y también vamos a instalar el resaltador de sintaxis para todo el código que se encuentra en los posts:

{% highlight bash%}
  gem install rouge
{% endhighlight %}

Como comenté en líneas anteriores, mi código está hosteado en GitHub y corre sobre GitHub Pages por lo que necesitamos la siguiente gema para poder ejecutar el servidor sin problemas:

{% highlight bash%}
  gem install github-pages
{% endhighlight %}

### Ejecutar Jekyll

Ya con lo necesario para poder comenzar a probar nuestro servidor, vamos a ejecutar lo siguiente para inicializar el servidor web:

{% highlight bash%}
  jekyll serve --host=0.0.0.0 --drafts
{% endhighlight %}

<p>Nota: Más adelante voy a tratar el tema de trabajar con Drafts en Jekyll :)</p>{: .notice--success}

Bueno... no todo salió como estaba previsto, al ejecutar el comando anterior se generó el siguiente error:

> Conversion error: Jekyll::Converters::Scss encountered an error while converting 'assets/css/styles.scss': Invalid US-ASCII character "\xE2" on line 54

Esto se debe a un error en la configuración del *locale* en el container. Debido a que no se puede modificar debido a la volatilidad, es necesario reflejar el cambio en el archivo de configuración.

Como la plataforma utiliza OpenVZ es necesrio modificar el archivo de conf, adicionando lo siguiente:

**"export LANG=en_US.UTF-8"**

Información relacionada:
* [Sitio de Jekyll](https://jekyllrb.com/)


Happy scripting!