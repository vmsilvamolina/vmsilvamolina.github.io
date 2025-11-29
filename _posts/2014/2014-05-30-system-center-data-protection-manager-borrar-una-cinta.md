---
title: 'Borrar una cinta en System Center Data Protection Manager'
date: 2014-05-30T17:09:02+00:00
author: Victor Silva
layout: post
permalink: /system-center-data-protection-manager-borrar-una-cinta/
dsq_thread_id:
  - "4493867188"
categories:
  - Data Protection Manager
tags:
  - DPM
  - Error ID 3316
  - mytape
  - Short Erase
---
En DPM trabajando con unidades de cinta, en alguna oportunidad nos podemos encontrar con errores de cinta. Uno de los errores puede ser el siguiente:

{% highlight plaintext %}
The detailed inventory of tape failed for the following reason: (ID: 3316)

The tape in Stand Alone Drive Tape Library Hewlett Packard LTO Ultrium-2 drive at Drive Hewlett Packard LTO Ultrium-2 drive has been written to by another tape backup application using an unsupported physical block size. DPM supports a physical block of 65536 bytes for writing and a physical block size ranging from 1024 bytes to 65536 bytes for reading. So DPM will not be able to read or overwrite the contents of this tape. (ID: 24084)
{% endhighlight %}

Como resultado de este error, DPM no puede escribir en la cinta, la cinta no se borra, y por lo tanto, no se puede utilizar para una tarea de respaldo. Buscando en internet, existen varios procedimientos y herramientas que no han funcionado. Incluso *DPMTapeUtil.Ps1*, no funcionó.

*DPMTapeUtil.Ps1* es una herramienta muy poderosa y útil para muchas otras tareas de por mas info, dejo un [enlace](http://blogs.technet.com/b/dpm/archive/2010/07/09/the-search-for-dpm-tape-utilities-stops-here.aspx).

Varios sitios se refieren a una herramienta llamada MyTape.exe. Hay sólo unos pocos lugares donde se puede descargar esta herramienta. Varias URL no eran válidas en el momento en que quería descargar la herramienta, y la descarga de MyTape.exe. Finalmente encontré el SkyDrive de Ruud Baar donde guarda un archivo llamado **DPMEraseTape.zip**.

El enlace para descargar el archivo, es el siguiente: [DPMEraseTape.zip](https://onedrive.live.com/?cid=b03306b628ab886f&id=B03306B628AB886F!862&sc=documents)

Ahora vamos con el procedimiento para borrar la cinta:

Lo primero que debemos hacer es acceder a la consola de DPM, ya que necesitamos obtener el ID de nuestra cinta. Para ello luego de acceder a la consola debemos ir a Bibliotecas (Library) y ya teniendo la cinta seleccionada, en detalles, hacer un clic con el botón derecho sobre nombre de la unidad (Tape ID) y luego copiar fila.

<img class="alignnone" src="https://lh3.googleusercontent.com/-AmPuo79jgQY/U54hn9yW-XI/AAAAAAAAFA8/NqSkTI92ooE/w1044-h452-no/DPM_Library_tape.png" alt="" width="750" height="325" />

Luego de tener en el portapapeles el Tape ID (por ejemplo: .Tape1234567890) debemos detener el servicio **DPMLA**.

<img class="alignnone" src="https://lh4.googleusercontent.com/-dvvo2XLqMVc/U54jseH9YnI/AAAAAAAAFBU/VTZZWaApQ8U/w821-h360-no/DPM_Library_service.png" alt="" width="582" height="255" />

Continuando el procedimiento, ya con el archivo descargado y realizada la extracción, debemos ejecutar una consola CMD y situarnos en la carpeta donde se encuentra el archivo MyTape.exe, y ejecutar lo siguiente:

<img class="alignnone" src="https://lh3.googleusercontent.com/-lZ-VArruuL8/U54jsHj3LMI/AAAAAAAAFBM/TkuvmjSiGb0/w674-h342-no/DPM_Library_cmd.png" alt="" width="566" height="287" />

Y luego cada uno de estos comandos:

  * `Loadtape`
  * `Taperewind`
  * `Erasetape`

Cuando ejecuten este último comando, van a poder elegir 2 opciones: Short Erase o Long Erase, por temas de tiempos les recomiendo elegir Short Erase (s) pero deben de corroborar de que pueden elegir esta opción, para ello chequear lo siguiente:

  1. En la ruta **HKEY\_LOCAL\_MACHINESOFTWAREMicrosoftMicrosoft\Data Protection ManagerAgent** crear la clave **UseShortErase.**
  2. Agregar como **DWORD** con el valor **0000000**.

<img class="alignnone" src="https://lh5.googleusercontent.com/-WChNdqbVu3U/U54j_DD578I/AAAAAAAAFBk/54MZIRQNeaY/w1021-h525-no/DPM_Library_reg.png" alt="" width="566" height="291" />

Con esto tendríamos listo el procedimiento para poder borrar la cinta correctamente.

Happy scripting!