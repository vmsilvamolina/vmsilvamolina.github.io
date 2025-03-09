---
title: 'Convertir un disco duro virtual VHD a un VHDX'
date: 2014-05-15T22:08:48+00:00
author: Victor Silva
layout: post
permalink: /convertir-un-disco-duro-virtual-vhd-a-un-vhdx/
dsq_thread_id:
  - "4471578415"
categories:
  - Hyper-V
  - PowerShell
tags:
  - Hyper-V
  - PowerShell
  - VHDX
  - VHD
---
En Windows 8 y Windows Server 2012 se introdujo un nuevo formato de disco duro virtual denominado **.VHDX** y hoy vamos a ver como convertir hacia este nuevo formato.


Existen varias mejoras al respecto entre las que se encuentran:

  * Mayor capacidad de almacenamiento, hasta un total de 64 Terabytes.
  * No es soportado por versiones anteriores a **Hyper-V 3.0**. Siendo la versión standard en Windows Server 2012 y Windows 8.
  * Tiene un tamaño por defecto de bloque más grande para discos fijos y diferenciales.
  * Protección contra la corrupción de datos ante fallas de energía.

Para convertir un disco .VHD a .VHDX lo vamos a hacer de 2 formas: Desde el **Hyper-V Manager** y desde **PowerShell**

## Hyper-v Manager

Abrimos la consola de **Hyper-V Manager **y nos vamos al panel de acciones, ahí seleccionamos la opción **_Editar disco..._**

<img src="https://lh5.googleusercontent.com/-fzB0uEgGth0/UHNZdQn_-kI/AAAAAAAAA8Q/yGqYuBkH3YI/w235-h297-no/hyperv1.png" alt="" width="235" height="297" />

Cuando inicie el asistente, le damos siguiente para poder empezar a seleccionar el disco y que vamos a hacer con él.

<img  src="https://lh6.googleusercontent.com/-2R44Nh7eMVE/UHNZdgWAVuI/AAAAAAAAA8U/obDK7wNDjhg/w718-h540-no/hyperv2.png" alt="" width="718" height="540" />

En Localizar disco, vamos con el botón de examinar a buscar la ruta donde se encuentra guardado nuestro .VHD

<img  src="https://lh4.googleusercontent.com/-cdCQSmmC8uQ/UHNZeYITnnI/AAAAAAAAA8g/JSgJz4UxO7w/w718-h540-no/hyperv3.png" alt="" width="718" height="540" />

En Elegir acción, vamos a seleccionar **_Convertirlo_** ya que la idea de nosotros es poder obtener el disco en formato .VHDX

<img src="https://lh5.googleusercontent.com/-HJ_dP0c-Mls/UHNZfGtH1gI/AAAAAAAAA8o/VnR3txCSXC4/w718-h540-no/hyperv4.png" alt="" width="718" height="540" />

Luego seleccionamos el formato de salida del archivo, en este caso va a ser _**VHDX**_.

<img src="https://lh3.googleusercontent.com/-2AAW1MoocoY/UHNZftI9LdI/AAAAAAAAA8w/ABw8DzNxdkU/w718-h540-no/hyperv5.png" alt="" width="718" height="540" />

Acá se puede elegir cualquiera de las 2, en este caso como era solamente para mostrar el procedimiento elegí _**Expansión** **Dinamica**_.

<img src="https://lh6.googleusercontent.com/-CR4b1aUdRrU/UHNZgH7cH3I/AAAAAAAAA84/wSnoFtXpMOY/w718-h540-no/hyperv6.png" alt="" width="718" height="540" />

Vamos a elegir la ruta donde vamos a querer que se guarde nuestro disco duro virtual, seleccionamos **_Examinar&#8230;_** y ahí navegamos hasta la carpeta seleccionada para tal fin.

<img src="https://lh5.googleusercontent.com/-f6fboHPqerY/UHNZghQrVRI/AAAAAAAAA9A/VMl0uyZe28Y/w718-h540-no/hyperv7.png" alt="" width="718" height="540" />

Con todos los datos ingresados correctamente estamos prontos para poder comenzar la conversión, para ello pulsamos el botón _**Finalizar...**_ y ahora a esperar a que se cree nuestro VHDX.

<img src="https://lh6.googleusercontent.com/-EMq0w8ifUrk/UHNZhEWYyLI/AAAAAAAAA9E/D8okmLPz2nQ/w718-h540-no/hyperv8.png" alt="" width="718" height="540" />

Bien, ahora ya tenemos nuestro disco .VHDX, pero que pasa si yo quiero automatizar un poco la tarea, o simplemente hacerlo de otra manera...

Para eso tenemos al maravilloso mundo del PowerShell!!

## PowerShell

Acá es bastante más rápido, simplemente vamos a tener que ejecutar el comando

{% highlight posh %}
Convert-VHD
{% endhighlight %}

Donde la sintaxis para este comando básicamente va a ser la siguiente:

> Convert-VHD [-Path] <Valor> [-DestinationPath] <Valor> [-VHDType <TipoVHD> ]

Como ejemplo vamos a poner que queremos convertir el disco **Test.vhd** que se encuentra en la carpeta **C:VMS** y lo queremos guardar en el mismo lugar pero con el nombre **Test-final** y que sea un disco** Dinámico**. Vamos a tener que ejecutar lo siguiente:

{% highlight posh %}
Convert-vhd -Path C:VMSTest.vhd -DestinationPath C:VMSTest-final.vhdx -VHDType Dynamic
{% endhighlight %}

Espero que les sea de utilidad.

Happy scripting!