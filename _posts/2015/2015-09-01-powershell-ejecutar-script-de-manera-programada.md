---
title: 'PowerShell - Ejecutar script de manera programada'
date: 2015-09-01T10:07:38+00:00
author: Victor Silva
layout: post
permalink: /powershell-ejecutar-script-de-manera-programada/
dsq_thread_id:
  - "4473168824"
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"203c4a86d22e";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:94:"https://medium.com/@vmsilvamolina/powershell-ejecutar-script-de-manera-programada-203c4a86d22e";}'
categories:
  - PowerShell
tags:
  - PowerShell
  - Tarea programada
  - Task Scheduler
---
Días atrás me encontré con la necesidad de recurrir al recurso de la tarea programada, para ejecutar periódicamente un script. En este post me voy a dedicar a compartir como sería el procedimiento para realizarlo.

Lo primero que necesitamos es tener el script guardado en un lugar accesible para poder acceder más adelante. En mi caso el script se encuentra en _C:\Users\Victor\Script.ps1_.

Lo siguiente que vamos a hacer es crear la tarea programada, accedemos a _Control Panel_ > _Administrative Tools_ > _Task Scheduler_.

Ya con la aplicación iniciada, vamos a **Create Task&#8230;**

<img src="https://lh5.googleusercontent.com/-s2Zv9Ewel50/VfgUYienR7I/AAAAAAAAHJ0/C8cCWl5KR38/w924-h563-no/PS_TaskScheduler_1.png" width="924" height="563" class="alignnone" />

En el campo Name, completamos con el nombre que queremos identificar esta tarea. Seleccionar la opción que indica que s eva a ejecutar con el usuario logueado o no. Y por último, si desean, configurar la tarea para que sea compatible con Windows 10 (en mi caso).

<img src="https://lh5.googleusercontent.com/-gFPxEL_mbsQ/VfgUZarYPlI/AAAAAAAAHJ8/rsF6U-CGJJE/w632-h480-no/PS_TaskScheduler_5.png" width="632" height="480" class="alignnone" />

En la pestaña **_Triggers_**, click en **New**. Agregar la periodicidad de la tarea. Para el ejemplo, indiqué que se realice todos los viernes a las 9:00hs.

<img src="https://lh4.googleusercontent.com/-r4Ia2EX8paE/VfgUYpxWAvI/AAAAAAAAHJo/J_Y8XDQbc7k/w591-h517-no/PS_TaskScheduler_2.png" width="591" height="517" class="alignnone" />

En la pestaña **_Actions_**, click en **New**. Dejamos la opción por defecto, para que inicie un programa, luego en el campo _Program_, escribimos PowerShell -File <ruta>, que en este caso sería:

    PowerShell -File "C:\Users\Victor\Script.ps1"
    

<img src="https://lh4.googleusercontent.com/-QpnrFVjDPLQ/VfgUYhJ4ZII/AAAAAAAAHJs/6RYvkacpBs8/w454-h500-no/PS_TaskScheduler_3.png" width="454" height="500" class="alignnone" />

Al seleccionar Ok, nos aparece la siguiente ventana, indicando si estamos de acuerdo en ejecutar el programa con los parametros indicados, le damos que si.

<img src="https://lh3.googleusercontent.com/-WWwSA5vPyps/VfgUZJRJddI/AAAAAAAAHJw/gRJmIG6-ROI/w482-h223-no/PS_TaskScheduler_4.png" width="482" height="223" class="alignnone" />

Y eso sería todo!

Ahora, desde la consola de PowerShell, podemos ejecutar algo así:

    $Action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument '-File C:\Users\Victor\Script.ps1'
    $Trigger =  New-ScheduledTaskTrigger -Daily -At 9am
    Register-ScheduledTask -Action $Action -Trigger $Trigger -TaskName "PowerShell Task" -Description "Tarea programada generada por la consola."
    

Saludos,