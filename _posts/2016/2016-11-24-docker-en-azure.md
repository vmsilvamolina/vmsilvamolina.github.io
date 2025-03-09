---
title: Utilizar Docker en Azure
date: 2016-11-24T12:27:50+00:00
author: Victor Silva
layout: post
permalink: /docker-en-azure/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"aea1d7360423";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:71:"https://medium.com/@vmsilvamolina/utilizar-docker-en-azure-aea1d7360423";}'
dsq_thread_id:
  - "5474444323"
categories:
  - Azure
  - Docker
tags:
  - Azure
  - Containers
  - Docker
  - docker images
  - docker pull
  - docker run
---
## Docker en Azure

En este post vamos a ver como utilizar docker en Azure para poder gestionar nuestros containers, así como también crear imágenes propias (próximo post) y hacer uso de ellas posteriormente.

Como requisito para empezar a trabajar es necesario contar un un host de Docker en Azure. Para ello, luego de haber ingresado al portal de Azure, vamos a **_New_** y buscamos _docker_. Como resultados vamos a tener una opción **Docker on Ubuntu Server** (que nos genera una instancia de Ubuntu 16.04 LTS con Docker ya instalado).

<img src="https://al9bmq-ch3302.files.1drv.com/y4mayztLSxbvwTdSnn4porw-lZJ4qlxBrfENRhyc4liDOfZ8u28kKZnIgldbkxRTn9sMJ1O6DLCs2W4zKOKHVTs_53avt_Y3bCVU8jvl6pTbGYIGjQ_EZu09yCyLURtxVzmoJiIswmYvJD46E1ajLpKIiIyQvfI93cRjYDurKqnpdae7ahyp10AxdAKqLW6N67Gs2Cd45QTyJmgPXPPcOklJg?width=1321&#038;height=728&#038;cropmode=none" width="1321" height="728" alt="Crear host de Docker en Azure" class="alignnone size-medium" />

Luego de seleccionar vamos a pulsar el botón **_Create_**. A partir de este momento debemos completar el asistente de implementación con los siguientes datos:

  * Hostname
  * Username/Password
  * Pricing tier
  * Resource Group
  * Location

Culminado el proceso, vamos a acceder a la VM y publicar 2 puertos para poder utilizarlos posteriormente (80 y 443). Este requerimiento lo realizamos accediendo a los endpoints de la VM, como indica la siguiente imagen:

<img src="https://al9amq-ch3302.files.1drv.com/y4m9H9JSUKg9U_zAdBOBlmI3_uWyY8O6PbKYl4JoLuu4meFhBu8mjsIplW-mzDnhzJpbCA_dJlBrgkMC6lLt-88rYR4i2SNutoCbC42fUuL8Zwwz91rreuxv1pBTZS5FUXBcwE95kOwt_0bWJK60zxdREJy-3HmgejKQ9sR9SchrrlvxunAT58rK9Gv4gD5scRwTr5mt9NBt4-E6WhZG_he4w?width=583&#038;height=601&#038;cropmode=none" width="508" height="404" alt="Agregar endpoints" class="alignnone size-medium" />

Y completamos los campos con los siguientes datos en orden:

  * **HTTP / 80 /80**
  * **HTTPS / 443 / 443**

<img src="https://al9amq-ch3302.files.1drv.com/y4m9H9JSUKg9U_zAdBOBlmI3_uWyY8O6PbKYl4JoLuu4meFhBu8mjsIplW-mzDnhzJpbCA_dJlBrgkMC6lLt-88rYR4i2SNutoCbC42fUuL8Zwwz91rreuxv1pBTZS5FUXBcwE95kOwt_0bWJK60zxdREJy-3HmgejKQ9sR9SchrrlvxunAT58rK9Gv4gD5scRwTr5mt9NBt4-E6WhZG_he4w?width=583&#038;height=601&#038;cropmode=none" width="583" height="601" alt="Asistente para agregar endpoints" class="alignnone size-medium" />

## Conexión con el host de Docker

Lo primero que vamos a hacer es conectarnos a nuestro host de Docker en Azure. Para ello vamos a abrir una consola de PowerShell y posteriormente ejecutar lo siguiente:

{% highlight posh %}
bash
{% endhighlight %}

Fácil, no? Bueno, en realidad con lo anterior solamente accedimos a nuestra consola de bash en Windows para poder utilizar el cliente ssh que trae incluido. En caso de que no tengan habilitada la feature de **_Bash on Ubuntu on Windows_**, les dejo un post anterior para que sepan como habilitarlo: [Habilitar Bash en Windows](http://blog.victorsilva.com.uy/habilitar-bash-windows/)

Para conectarnos por ssh desde nuestra consola basta ejecutar:

{% highlight posh %}
ssh ejemplodockerhost.cloudapp.net 22
{% endhighlight %}

Nos aparecerá una advertencia indicando que no se conoce al host y si realmente queremos conectarnos, al escribir _yes_ automáticamente se agrega el host como conocido. A partir de estos momentos estamos conectados a nuestro host de Docker en Azure.

## Docker

Para comenzar a trabajar con Docker vamos a ver como hacemos para conocer los containers que se encuentran en ejecución en nuestro host, con el comando **ps**, de la siguiente manera:

{% highlight posh %}
docker ps
{% endhighlight %}

Y para tener una lista de las imágenes que disponemos en el host, el comando es **images**:

{% highlight posh %}
docker images
{% endhighlight %}

<img src="https://al9cmq-ch3302.files.1drv.com/y4mrXBvRlkg1rH0-Nic7pn1xMp-T0zk0eNLFan3owlfBi8dn5DuxDDkwcVMmgDiqUvjW9_Xdt5phtCHZ_QR7As5cvKru5_K00alhoyQuHtV6w33MrQ6DZjc-6qgb4O8C0ylbeuT8nfP_MLxsHRerhgQms80RdSoxWhR8dT0HwhM5bIVUYjBVwY9MZUG3SUmoqAUfZkta2cGd52UqNBFkHadRQ?width=871&#038;height=347&#038;cropmode=none" width="871" height="347" alt="Docker en Azure" class="alignnone size-medium" />

Es obvio que el resultado de ambos comandos es en blanco, ya nos encontramos sobre una instalación limpia. Así que vamos a comenzar a creando un container para comprobar el funcionamiento correcto de la plataforma y de los endpoints que configuramos.

En cuestión, vamos a hacer el "
Hola mundo!"
 de los containers:

{% highlight posh %}
docker run ubuntu /bin/echo 'Hello world'
{% endhighlight %}

Ok, parece que solo imprimimos un mensaje en pantalla, pero realmente se realizó la descarga de la imagen ubuntu y se generó un container a partir de esa imagen, al que se le especificó que imprimiera un msje en particular. ¿Cómo podemos comprobar que se descargó la imagen en cuestión? De la siguiente manera:

{% highlight posh %}
docker images
{% endhighlight %}

<img src="https://q15imq-ch3302.files.1drv.com/y4mOSkcgvu_XdPk-w6IKkGuWDlKV33p68qbjecuDmUInYmkxQQZMtbdFc5FpInGhLL9WLNziVldwvt048nGRl8lqQIOD_5RpPmuM8EDJwOKz74Hc9usSbASp-MuDClTQLVcbav6wjAu6b-pBUAKSTNUGSht_3juDn3F0W9GB-chkkjrffuHq9bFoOvCSSDbKZPTbo0yU-0F15NlS77QCRQFCg?width=888&#038;height=291&#038;cropmode=none" width="888" height="291" alt="Usar la imagen Ubuntu para nuestro container" class="alignnone size-medium" />

Como muestra la imagen anterior vemos que existe una imagen en nuestro store local y a su vez, tenemos un container corriendo en nuestro host.

## Descargar una imagen en particular

En caso de conocer la imagen que pretendemos utilizar en el host, existe el comando **pull** que nos permite realizar esta tarea:

{% highlight posh %}
docker pull jekyll/jekyll
{% endhighlight %}

Que nos permite descargar según el ejemplo la imagen oficial de Jekyll (generador estático para blogs).

Happy scripting!
