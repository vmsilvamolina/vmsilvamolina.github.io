---
title: 'Windows Server 2012 - Failure configuring Windows updates. Reverting changes...'
date: 2015-08-06T22:58:33+00:00
author: Victor Silva
layout: post
permalink: /windows-server-2012-failure-configuring-windows-updates-reverting-changes/
dsq_thread_id:
  - "4484305340"
categories:
  - Windows Server
tags:
  - "2012"
  - Updates
  - Windows Server
  - WS
  - WS 2k12
---
En Windows Server 2012, luego de que se instalaran los updates correspondientes, me encuentro con la necesidad de reiniciar el servidor para que se terminen de instalar y aplicar los parches correspondientes.

Pocos segundos antes de que termine el proceso de instalación, me encuentro con un cartel que indica lo siguiente:

> Failure configuring Windows updates. Reverting changes...

Y empieza a revertir los cambios... así de la nada.

Espero que termine el proceso de vuelta atrás, inicio sesión y reviso los logs. Poca info...
  
Revisando por varios blogs, encuentro un dato importante en el blog de la TechNet ([enlace](https://social.technet.microsoft.com/Forums/windowsserver/en-US/70219bcb-36a8-466e-900b-cbf390db38d2/failure-configuring-windows-updates-reverting-changes-postreboot-status-0x800f0922?forum=winserver8gen)). La solución: Eliminar una clave del registro de Windows.

Ok, ingreso al registro, hago un backup de la Key y paso a eliminar lo siguiente:

> HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Publishers&#123;e7ef96be-969f-414f-97d7-3ddb7b558ccc}

Perfecto!

Espero que les sirva el dato.

Happy scripting!