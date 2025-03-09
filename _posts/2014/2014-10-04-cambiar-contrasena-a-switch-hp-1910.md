---
title: 'Cambiar contraseña a Switch HP 1910'
date: 2014-10-04T01:45:09+00:00
author: Victor Silva
layout: post
permalink: /cambiar-contrasena-a-switch-hp-1910/
dsq_thread_id:
  - "4473209710"
categories:
  - Networking
tags:
  - Cambiar contraseña
  - HP
  - Networking
---
Pocas veces me ha tocado la necesidad de sumergirme en estos tipos de temas. Pero pasó... perdí la clave de administrador de un Switch HP 1910, por eso comparto mi humilde manera de forzar el cambio de contraseña.

Lo primero que tengo que decir, es que contaba con un backup de la configuración (reciente). Lo segundo es que usé _Putty_ para conectarme (con el cable a la consola, obviamente).

Antes de comenzar a toquetear el switch, debemos de instalar en nuestro equipo un servidor _TFTP_, buscando van a encontrar varios, gratis y todo. Descargar, instalar, iniciar. Luego de este requisito pasamos a meter mano.

Vamos a iniciar el procedimiento, reiniciando el switch. Durante el reinicio aparecerá un menú (del tipo que aparece en los BIOS) donde deberemos pulsar la combinación de teclas _Ctrl + B_, para poder acceder al menú de opciones.

> Press Ctrl-B to enter Boot Menu...

Ya pulsada la combinación de teclas, nos desplegará el siguiente menú:

{% highlight plaintext%}
  BOOT  MENU
  1. Download application file to flash
  2. Select application file to boot
  3. Display all files in flash
  4. Delete file from flash
  5. Modify bootrom password
  6. Enter bootrom upgrade menu
  7. Skip current configuration file
  8. Set bootrom password recovery
  9. Set switch startup mode
  10. Reboot
  Enter your choice(0-9):
{% endhighlight %}

Dentro de este menú debemos pulsar la tecla 7, que selecciona la opción:

> Skip current configuration file

Y finalmente pulsar la tecla 0 para reiniciar el dispositivo.

Ya reiniciado, nos va a loguear automaticamente y desde la consola vamos a poder ejecutar el siguiente comando:

{% highlight plaintext%}
_cmdline-mode on
{% endhighlight %}

<img class="alignnone" src="https://lh3.googleusercontent.com/-ds9k7lkFq9E/VH5LY53Pr4I/AAAAAAAAGOQ/ybGf-Gg-pZk/w595-h202-no/HP1910_1.png" alt="" width="595" height="202" />

Después de ingresar el comando nos va a pedir una clave, si no la modificamos, por defecto es **512900**.

El comando anterior nos va a habilitar una lista "secreta" de comandos para poder realizar mas acciones, entre ellas levantar un archivo de configuración nuevo. El comando que va a ejecutar lo que necesitamos es restore.

Antes de ejecutar el comando restore, debemos modificar en el archivo de configuración (lo abrimos con un notepad, así de fácil) la contraseña del usuario correspondiente. Para ello buscamos la línea que indica este dato y la modificamos. Si la contraseña esta cifrada (va a aparecer como cipher) debemos cambiar esta palabra por "simple" y escribir la contraseña tal cual queremos que sea (por ejemplo **Pa$$w0rd.2015**). Guardamos este cambio en el archivo de configuración y vamos a situarlo en la carpeta que el software de TFTP nos indique para que quede disponible para realizar la transferencia.

Ahora sí, con todo listo, vamos a ejecutar el comando restore aclarando que la sintaxis del comando para restaurar el archivo de configuración anterior (.cfg) es la siguiente:

{% highlight plaintext%}
restore startup-configuration from <IP del Servidor TFTP> <Nombre del archivo.cfg>
{% endhighlight %}

Luego de hacer este restore, reiniciamos el dispositivo y vamos a poder acceder a nuestro Switch con la contraseña que nosotros detallamos anteriormente.

Happy scripting!