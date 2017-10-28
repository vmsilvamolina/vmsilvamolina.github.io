---
id: 403
title: 'System Center Data Protection Manager &#8211; Borrar una cinta'
date: 2014-05-30T17:09:02+00:00
author: Victor Silva
layout: simple
guid: http://blog.victorsilva.com.uy/?p=403
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

<!--more-->

> The detailed inventory of tape failed for the following reason: (ID: 3316)
> 
> The tape in Stand Alone Drive Tape Library Hewlett Packard LTO Ultrium-2 drive at Drive Hewlett Packard LTO Ultrium-2 drive has been written to by another tape backup application using an unsupported physical block size. DPM supports a physical block of 65536 bytes for writing and a physical block size ranging from 1024 bytes to 65536 bytes for reading. So DPM will not be able to read or overwrite the contents of this tape. (ID: 24084)

<span id="result_box" lang="es"><span class="hps">Como resultado de este error</span><span>, DPM</span> <span class="hps">no puede escribir en</span> <span class="hps">la cinta,</span> <span class="hps">la cinta no</span> <span class="hps">se borra</span>, y<span> por lo tanto,</span> <span class="hps">no se</span> <span class="hps">puede utilizar para una</span> <span class="hps">tarea de respaldo.</span><br /> <span class="hps">Buscando en internet, existen varios procedimientos y herramientas que no han funcionado</span><span class="hps">.</span> <span class="hps">Incluso</span> <strong><span class="hps">DPMTapeUtil.Ps1</span></strong><span>,</span> <span class="hps">no funcionó.</span> </span>

<span id="result_box" lang="es"><span class="hps atn">&#8220;</span><span>DPMTapeUtil.Ps1</span><span>&#8220;</span> <span class="hps">es una herramienta muy</span> <span class="hps">poderosa y útil</span> <span class="hps">para muchas</span> <span class="hps">otras tareas</span> <span class="hps">de DPM</span><span>.</span></span> por mas info, dejo un [enlace](http://blogs.technet.com/b/dpm/archive/2010/07/09/the-search-for-dpm-tape-utilities-stops-here.aspx).

<span id="result_box" lang="es"><span class="hps">Varios sitios</span> <span class="hps">se refieren a una</span> <span class="hps">herramienta llamada</span> <span class="hps">MyTape.exe</span>. <span class="hps">Hay sólo unos</span> <span class="hps">pocos lugares</span> <span class="hps">donde se puede descargar</span> <span class="hps">esta herramienta.</span> <span class="hps">Varias</span> <span class="hps">URL</span> <span class="hps">no</span> <span class="hps">eran válidas</span> <span class="hps">en el momento en</span> <span class="hps">que quería</span> <span class="hps">descargar la herramienta,</span> <span class="hps">y la descarga de</span> <span class="hps">MyTape.exe</span><span class="hps">.</span> <span class="hps">Finalmente</span> <span class="hps">encontré el</span> <span class="hps">SkyDrive</span> <span class="hps">de</span> <span class="hps">Ruud</span> <span class="hps">Baar</span> <span class="hps">donde guarda</span> <span class="hps">un </span><span class="hps">archivo llamado</span> <strong><span>DPMEraseTape.zip.</span></strong> </span>

El enlace para descargar el archivo, es el siguiente: [DPMEraseTape.zip](https://onedrive.live.com/?cid=b03306b628ab886f&id=B03306B628AB886F!862&sc=documents)

Ahora vamos con el procedimiento para borrar la cinta:

Lo primero que debemos hacer es acceder a la consola de DPM, ya que necesitamos obtener el ID de nuestra cinta. Para ello luego de acceder a la consola debemos ir a Bibliotecas (Library) y ya teniendo la cinta seleccionada, en detalles, hacer un click con el botón derecho sobre nombre de la unidad (Tape ID) y luego copiar fila.

<img class="alignnone" src="https://lh3.googleusercontent.com/-AmPuo79jgQY/U54hn9yW-XI/AAAAAAAAFA8/NqSkTI92ooE/w1044-h452-no/DPM_Library_tape.png" alt="" width="750" height="325" />

Luego de tener en el portapapeles el Tape ID (por ejemplo: .Tape1234567890) debemos detener el servicio **DPMLA**.

<img class="alignnone" src="https://lh4.googleusercontent.com/-dvvo2XLqMVc/U54jseH9YnI/AAAAAAAAFBU/VTZZWaApQ8U/w821-h360-no/DPM_Library_service.png" alt="" width="582" height="255" />

Continuando el procedimiento, ya con el archivo descargado y realizada la extracción, debemos ejecutar una consola CMD y situarnos en la carpeta donde se encuentra el archivo MyTape.exe, y ejecutar lo siguiente:

<img class="alignnone" src="https://lh3.googleusercontent.com/-lZ-VArruuL8/U54jsHj3LMI/AAAAAAAAFBM/TkuvmjSiGb0/w674-h342-no/DPM_Library_cmd.png" alt="" width="566" height="287" />

Y luego cada uno de estos comandos:

  * **Loadtape**
  * **Taperewind**
  * **Erasetape**

Cuando ejecuten este último comando, van a poder elegir 2 opciones: Short Erase o Long Erase, por temas de tiempos les recomiendo elegir Short Erase (s) pero deben de corroborar de que pueden elegir esta opción, para ello chequear lo siguiente:

  1. En la ruta **HKEY\_LOCAL\_MACHINESOFTWAREMicrosoftMicrosoft** <span style="font-weight: bold;">Data Protection ManagerAgent</span> crear la clave **UseShortErase.**
  2. Agregar como **DWORD** con el valor <span style="font-weight: bold;">0000000.</span>

<img class="alignnone" src="https://lh5.googleusercontent.com/-WChNdqbVu3U/U54j_DD578I/AAAAAAAAFBk/54MZIRQNeaY/w1021-h525-no/DPM_Library_reg.png" alt="" width="566" height="291" />

Con esto tendriamos listo el procedimiento para poder borrar la cinta correctamente.

Saludos,