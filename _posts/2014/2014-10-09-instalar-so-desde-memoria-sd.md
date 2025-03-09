---
title: 'Instalar SO desde memoria SD'
date: 2014-10-09T11:34:46+00:00
author: Victor Silva
layout: post
permalink: /instalar-so-desde-memoria-sd/
dsq_thread_id:
  - "4652211885"
categories:
  - Windows
tags:
  - Instalar Windows
  - memoria SD
  - Windows 8.1 SD
---
A veces tenemos que recurrir a métodos no muy convencionales para poder trabajar o realizar tareas en particular. Y eso fue lo que me paso hace unos días.

Resulta que tenía una notebook ala cuál le iba a instalar Windows 8.1 pero no tenía medios de instalación ni pendrives para poder hacer la instalación. Lo único que tenía era una camara de fotos con una memoria SD de 16GB. Con la memoria realicé el siguiente procedimiento y pude realizar la instalación.

Lo primero es abrir una consola de comandos con permisos de administrador.

Ya con la consola desplegada y con la memoria insertada en la notebook, tenemos que ejecutar lo siguiente:

{% highlight bash %}
diskpart
list disk
select disk X #donde X es el número de la SD
clean
create partition primary
select partition X #donde X es el número de la SD
active
format fs=fat32
{% endhighlight %}

<img src="https://lh4.googleusercontent.com/-HSVnAGtf3vU/VJgdB83AHKI/AAAAAAAAGUc/_kf7njFo-p4/w551-h567-no/DISKPART_SD_W8.png" width="551" height="567" class="alignnone" />

Después de que termine el proceso de formateo, debemos copiar a la SD, todos los archivos que trae la ISO de Windows 8.1

Y eso fue todo. Basta con bootear desde la memoria SD para poder comenzar la instalación.

Happy scripting!