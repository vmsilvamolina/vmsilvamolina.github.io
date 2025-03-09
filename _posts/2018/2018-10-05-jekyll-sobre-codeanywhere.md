---
title: "Ejecutar Jekyll sobre Codeanywhere"
author: Victor Silva
date: 2018-10-05T21:47:00+00:00
layout: post
permalink: /jekyll-sobre-codeanywhere/
excerpt: "Hace un tiempo que estoy intentando librarme de ambientes locales a la hora de escribir en el blog porque, si bien me encanta Jekyll como generador de contenido estático, tiene un requisito que es el siguiente: Para poder ver los cambios y/o borradores es necesario ejecutar el blog."
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

<img src="https://hjf8iw.ch.files.1drv.com/y4m7fXaKO53b8FZvF2QkbhE-ofa04Tu65Ho32dLug5bL9T-3ZzmglC1bOTTNK9U3xJNA2Mv2MXywiT5D5XFhnobxU1HAQZFZunSvK9DAukPgcCQcvGXTNSFwGvDPh-DFsDqtX71QaYmuOeQi7-U5N4BHP5UBQ0SAwtyH2XvxepNWOioWg17j6d7MaSym4afBKbDA3LunLmX-oVwGnZFVPHQNg?width=1187&height=835&cropmode=none" width=1187 height=835 alt="Container en Codeanywhere" class="alignnone" />

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

<div><b>Nota:</b> Más adelante voy a tratar el tema de trabajar con Drafts en Jekyll :)</div>{: .notice--success}

Bueno... no todo salió como estaba previsto, al ejecutar el comando anterior se generó el siguiente error:

> Conversion error: Jekyll::Converters::Scss encountered an error while converting 'assets/css/styles.scss': Invalid US-ASCII character "\xE2" on line 54

<img src="https://iayjxg.ch.files.1drv.com/y4mxMcUvlYSqPy41HUt7gKEfX23ft7oxak4_HJH_JTdqFOZILHCAdnhzUsJjJsYqX8MqsSJDhHqOOXtLgavu8OM_RzzzesJR-HHqleNwLDmJlCkEyMRh9VV6lYTgANtHGRmO7WVnDcBvqqGFxQA3oBVHfx5qT0DedpABvYV-onjZ7bwDWZAR3BO81N75ItS7l7ApO0rPf79JCDN9qshdOt7mA?width=1179&height=403&cropmode=none" alt="Conversion error: Jekyll::Converters::Scss encountered an error while converting 'assets/css/styles.scss'" class="alignnone" />

Esto se debe a un error en la configuración del *locale* en el container. Debido a que no se puede modificar debido a la volatilidad, es necesario reflejar el cambio en el archivo de configuración.

Como la plataforma utiliza OpenVZ es necesrio modificar el archivo de conf, adicionando lo siguiente:

**"export LANG=en_US.UTF-8"**

<img src="https://kppo8w.ch.files.1drv.com/y4mRRb4rdUfaWVMnLZdSsRK_P20lNZ0Td_Re_5vn-dbD9RzKqwxAr0O8aTeAS2G4aflzE8QMEMGubenDaNgv2i9tjlI-OEKd1LrFKEMyP1FiyoH39mnpQjcHjbEpFIY-v3k308YIDiz12Hz2AL74sagwVTJ6WZ-ZfLIKsgbdWcPKvvLGT9y_-nt3ELmugKQxjCuLvo4_ca6N1Fl2YrZvVyHeA?width=1284&height=791&cropmode=none" alt="Configuración de OpenVZ" class="alignnone" />

Información relacionada:
* [Sitio de Jekyll](https://jekyllrb.com/)


Happy scripting!