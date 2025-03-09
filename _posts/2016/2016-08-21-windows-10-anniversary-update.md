---
title: Windows 10 Anniversary Update en WSUS
date: 2016-08-21T15:00:29+00:00
author: Victor Silva
layout: post
permalink: /windows-10-anniversary-update/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";N;s:10:"author_url";N;s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";N;s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:4:"none";s:3:"url";N;}'
dsq_thread_id:
  - "5260049724"
categories:
  - PowerShell
  - Windows Server
tags:
  - "1607"
  - Windows 10
  - Windows 10 Anniversary Update
  - WSUS
---
Windows 10 Anniversary Update se ha traído cambios no solo a nivel de Sistema Operativo, si no también cambios a la hora de ser administrado, particularmente hablando de los Windows Updates. Es por ello que nos encontramos con una situación particular en nuestros servidores de WSUS, básicamente tenemos que actualizar el rol de Windows Server utilizando el [KB3095113](https://support.microsoft.com/en-us/kb/3095113): **_Update to enable WSUS support for Windows 10 feature upgrades_**, el cuál corrige el tipo de Sistema Operativo de los equipos (los equipos con Windows 10 se muestran como _Windows Vista_).

Si bien la situación actual no limita continuar desplegando los updates críticos y de seguridad liberados para el sistema operativo, no es posible entregar las funciones nuevas que se han liberado, como por ejemplo la actualización **1607** (_Windows 10 Anniversary Update_), que aparte de ser una actualización de seguridad (crítica) provee nuevas features (detalles en <https://technet.microsoft.com/en-us/itpro/windows/whats-new/whats-new-windows-10-version-1607>).

## Limpieza de la base

Luego de instalada la actualización para WSUS, debemos ejecutar una limpieza de la base para actualice el catálogo correspondiente. Para ello es necesario ejecutar el siguiente procedimiento desde PowerShell:

{% highlight posh %}
# Para todos los updates del tipo upgrade, se deshabilita la clasificación
Get-WsusClassification | Where-Object -FilterScript {$_.Classification.Title -Eq “Upgrades”} | Set-WsusClassification -Disable

# eliminar todos los updates que pertenecen a la version 1511
$s = Get-WsusServer
$s.SearchUpdates(“version 1511, 10586”) | foreach { $s.DeleteUpdate($_.Id.UpdateId) } 

# habilitar la clasificación de los updates del tipo upgrade
Get-WsusClassification | Where-Object -FilterScript {$_.Classification.Title -Eq “Upgrades”} | Set-WsusClassification 

#realizar una sincronización
$sub = $s.GetSubscription()
$sub.StartSynchronization()
{% endhighlight %}

Luego de ejecutar lo anterior, podemos observar desde la consola de WSUS que el resultado del informe de sincronización ya está mostrando el upgrade de _Windows 10 Anniversary Update_:

<img src="https://oy9cda-ch3302.files.1drv.com/y4msD79Ys6iOC7WyKfqR9G7BoGXpgBOX0NwY7Jgzu2ZygI3CFtK0TFszato7Wel9yGwQEH0_se1xOcfVIwACbLxQVNNTTwQNZDupiVm3dqCNFQrzwAnTAL0UzgYFCKIIJCUMDDwT-ye-EIfDOxO9vNhvhd1_AZdsiAma6SH41ztg85aNRwVNN6FUxP-sZeiFZwMdAJ58UgC8r7QaRzMjkg0Hg?width=814&#038;height=498&#038;cropmode=none" width="814" height="498" alt="Windows 10 Anniversary Update" class="alignnone size-medium" />

Solo resta esperar que se descargue el upgrade en el servidor WSUS para, luego de aprobarlo, inicie la distribución en los equipos.

Happy scripting!