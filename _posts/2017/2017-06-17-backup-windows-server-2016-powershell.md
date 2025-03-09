---
title: Backup en Windows Server 2016 con PowerShell
date: 2017-06-17T21:59:46+00:00
author: Victor Silva
layout: post
permalink: /backup-windows-server-2016-powershell/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"14bdaff40cfd";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:91:"https://medium.com/@vmsilvamolina/backup-en-windows-server-2016-con-powershell-14bdaff40cfd";}'
dsq_thread_id:
  - "6014862483"
categories:
  - PowerShell
  - Windows Server
tags:
  - BackUp
  - PowerShell
  - Windows Backup
  - Windows Server
  - Windows Server 2016
---
Todos los administradores de sistemas en algún momento han tenido que lidiar con problemas de respaldos: desde los software de Backup que no funcionan o la falta de seguimiento de los trabajos. Ésto hace que al momento de requerir un respaldo en muchas oportunidades la respuesta sea negativa. Por todo lo anterior y más, es que he decidido escribir un pequeño artículo sobre como realizar el backup en Windows Server 2016.

Dentro de las características que ofrece Windows Server 2016 (y también presente en versiones anteriores), siendo una de las más importantes creo yo, es la capacidad de realizar respaldos o Backups de nuestros servidores. Si bien la mayoría de las empresas hoy por hoy deben contar con una solución para obtener copias de seguridad, no todo el mundo sabe que se puede utilizar el mismo Windows Server para este fin y sin costo alguno. Por ello hoy vamos a ver como trabajar con esta feature y como no, desde nuestro querido PowerShell, para no perder la costumbre.

## Backup en Windows Server 2016 con PowerShell

Partimos desde la necesidad de conocer si tenemos habilitada o no esta característica en nuestro servidor a respaldar, por ello debemos ejecutar el siguiente comando para obtener la respuesta:

{% highlight posh %}
Get-WindowsFeature | ? {$_.DisplayName -match "Backup"}
{% endhighlight %}

Obteniendo como resultado (si no está habilitada) la siguiente imagen:

<img src="https://du00fw-ch3302.files.1drv.com/y4mikE3gX85OaOv0pgDO7icZAuKuLF3bMp6roj9mtl6rOVCMhPc7fiIEGdd3SKA7itEkawmmclBXZG-VV_tc2fOA5cEXXQ-uPL_M-ctGuscXxs7NV5LxvQ74kCJe9EXXCsYYkIauwU-1Jj2BxNrP59b-OO6Sj9MPAl60FzEzoDUoiiZ1-UbI9XFy3FL-vyrptZZQUq2JOQEPEAnqC_RUhMicw?width=858&#038;height=183&#038;cropmode=none" width="858" height="183" alt="Backup en Windows Server 2016" class="alignnone size-medium" />

Para habilitar el rol de Windows Server Backup en el servidor que nos encontramos trabajando, tenemos que ejecutar la siguiente línea de código:

{% highlight posh %}
Add-WindowsFeature -Name Windows-Server-Backup
{% endhighlight %}

Luego de finalizado el proceso, si volvemos a ejecutar el primer comando, en la columna _Install State_ debe de aparecer _Installed_. Teniendo la característica habilitada deberemos de configurar la política que ejecutará los trabajos.

Cómo creamos la política que gestionará nuestros trabajos de backup? Muy fácil, debemos ejecutar:

{% highlight posh %}
$Policy = New-WBPolicy
{% endhighlight %}

Este procedimiento pretende tomar como destino (de los archivos de backup) una unidad de red, así que antes de continuar con los siguientes pasos tenemos que tener la carpeta destino ya compartida y con los permisos de escritura.

Continuando con el proceso tenemos que setear los parámetros en la política para que pueda recuperar backups del tipo bare metal y el componente system state:

{% highlight posh %}    
  $Policy | Add-WBBareMetalRecovery
  $Policy | Add-WBSystemState
{% endhighlight %}

Agrego los discos críticos como volúmenes para respaldar en el servidor:

{% highlight posh %}
$Volumes = Get-WBVolume -CriticalVolumes
  Add-WBVolume -Policy $Policy -Volume $Volumes
{% endhighlight %}


Se define el destino de los respaldos, en este caso, voy a utilizar un recurso compartido de red (el servidor “<serverName>” y la carpeta compartida “BKP”):

{% highlight posh %}
$BackupLocation = New-WBBackupTarget -NetworkPath "\\<serverName>\BKP" -Credential
  Add-WBBackupTarget -Policy $Policy -Target $BackupLocation
{% endhighlight %}

Defino la programación, en este ejemplo quiero que se realice en 10 minutos, por lo que agrego:

{% highlight posh %}
Set-WBSchedule -Policy $Policy -Schedule ([datetime]::Now.AddMinutes(10))
{% endhighlight %}

Y por último me resta iniciar el trabajo

{% highlight posh %}
Start-WBBackup -Policy $Policy
{% endhighlight %}

Si todo lo anterior se ejecutó sin problemas, en 10 minutos comenzará a respaldar el servidor.

## Bloque de código

A continuación comparto el bloque de código todo junto, comentado y agrego al inicio una parte lógica para que compruebe si la característica de Windows Backup está habilitada (en caso contrario, va a realizar la instalación de la misma):

{% highlight posh %}
#Compruebo si la feature BackUp esta habilitada, en caso contrario la habilito.
  $WSB = Get-WindowsFeature -Name Windows-Server-Backup
  If ($WSB.Installed -ne "True") {
    Add-WindowsFeature -Name Windows-Server-Backup 
  }

  #Genero la política para el respaldo
  $Policy = New-WBPolicy

  #Agrego los parámetros necesarios
  $Policy | Add-WBBareMetalRecovery
  $Policy | Add-WBSystemState

  #Agrego los discos a respaldar
  $Volumes = Get-WBVolume -CriticalVolumes
  Add-WBVolume -Policy $Policy -Volume $Volumes

  #Agrego el destino, en este caso el recurso de red compartido BKP en Server
  $BackupLocation = New-WBBackupTarget -NetworkPath "\\<serverName>\BKP"
  Add-WBBackupTarget -Policy $Policy -Target $BackupLocation

  #Defino la programación (10 minutos desde el comienzo del Job)
  Set-WBSchedule -Policy $Policy -Schedule ([datetime]::Now.AddMinutes(10))

  #Inicio el Job
  Start-WBBackup -Policy $Policy
{% endhighlight %}

Happy scripting!