---
title: 'PowerShell - Reemplazar cmd en el menú secundario del botón inicio (Windows 8.1 / Server 2012 R2)'
date: 2014-10-15T12:21:59+00:00
author: Victor Silva
layout: single
permalink: /powershell-reemplazar-el-cmd-en-el-menu-secundario-del-boton-inicio-windows-8-1-server-2012-r2/
dsq_thread_id:
  - "4493255871"
categories:
  - PowerShell
  - Windows
tags:
  - Acceso
  - Menú inicio secundario
  - PowerShell
  - Windows
---
En caso de que usen demasiado PowerShell,o que les guste tanto como a mi, podemos establecer este cambio en el menú secundario del inicio.

Por las dudas si no tienen claro cual es el menú del que estoy hablando les dejo un imagen:

<img src="https://lh6.googleusercontent.com/-U0fWAjvLnr8/VM1MmtF7r3I/AAAAAAAAGyQ/Fxk-EC3wnIA/w307-h431-no/PS_Start_Menu.png" width="356" height="468" class="alignnone" />

Si bien es cierto que podemos acceder a esta herramienta (PowerShell) de diversas maneras, esta me parece una forma interesante y que se desconoce en la gran mayoría de las veces.

Para configurar esto debemos acceder las propiedades de las barra de tareas, accediendo con el botón derecho:

<img src="https://lh4.googleusercontent.com/-HGpbj1xKOfM/VJhY542FCWI/AAAAAAAAGVU/BICsPUduUTQ/w431-h235-no/PS_START_MENU_2.png" width="431" height="235" class="alignnone" />

Luego debemos ir a la pestaña navegación:

<img src="https://lh3.googleusercontent.com/-Gki_TrNDDRE/VJhY56XHlOI/AAAAAAAAGVM/CN8j9M-r-9c/w414-h521-no/PS_START_MENU_3.png" width="414" height="521" class="alignnone" />

Y dentro de las opciones de la pestaña, seleccionar la que dice: "
Reemplazar el símbolo del sistema por Windows PowerShell en el menú&#8230;"


<img src="https://lh6.googleusercontent.com/-AWyQAEFiJ_U/VJhY5zTU50I/AAAAAAAAGVQ/ytSVlHVP1hM/w414-h521-no/PS_START_MENU_4.png" width="414" height="521" class="alignnone" />

Y listo! Si accedemos nuevamente al menú, ya sea con la combinación de teclas Windows + X o seleccionando con el botón derecho el icono de inicio, nos aparecerá la opción de iniciar Windows PowerShell 🙂

<img src="https://lh5.googleusercontent.com/-XRMcqZhsUfM/VJhbxD20RzI/AAAAAAAAGVg/6eMz8xhBNzI/w357-h457-no/PS_START_MENU_5.png" width="357" height="457" class="alignnone" />

Happy scripting!