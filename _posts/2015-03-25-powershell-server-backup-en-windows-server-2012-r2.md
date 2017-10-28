---
id: 525
title: 'PowerShell &#8211; Server Backup en Windows Server 2012 R2'
date: 2015-03-25T15:41:21+00:00
author: Victor Silva
layout: simple
guid: http://blog.victorsilva.com.uy/?p=525
permalink: /powershell-server-backup-en-windows-server-2012-r2/
dsq_thread_id:
  - "4491609989"
categories:
  - PowerShell
tags:
  - BackUp
  - Cmdlet
  - Get-WindowsFeature
  - PowerShell
  - Windows Backup
---
Dentro de las características que trae Windows Server 2012 R2 (también presente en versiones anteriores), y una de las más importantes creo yo, es el tema de los respaldos o Backups. Si bien la mayoría de las empresas deben contar con una solución para obtener copias de seguridad, no todo el mundo sabe que se puede utilizar el mismo Windows Server para este fin y sin costo alguno. Por ello hoy vamos a ver como trabajar con esta _feature_ y como no, desde nuestro querido PowerShell.

Lo primero que nos vamos a responder es si ya tenemos o no habilitada esta característica en nuestro servidor a respaldar, por ello debemos ejecutar el siguiente comando para obtener esta respuesta:

    Get-WindowsFeature | ? {$_.DisplayName -match "Backup"}
    

Obteniendo como resultado (si no está habilitada) la siguiente imagen:

<img src="https://lh4.googleusercontent.com/-U1Mpji5BkUU/VQ1dsNZXLpI/AAAAAAAAG4o/e8NB7BmhQJ8/w696-h128-no/PS_BKP_1.png" width="696" height="128" class="alignnone" />

Para habilitar el rol de Windows Server Backup en el servidor que estamos trabajando, tenemos que ejecutar la siguiente línea de código:

    Add-WindowsFeature -Name Windows-Server-Backup
    

Luego de finalizado el proceso, si volvemos a ejecutar el primer comando, en la columna **_Install State_** debe de aparecer _Installed_. Teniendo la característica habilitada deberemos de configurar la política que ejecutará los trabajos.

Cómo creamos la política que gestionará nuestros trabajos de backup? Muy fácil, debemos ejecutar:

    $Policy = New-WBPolicy
    

Este procedimiento prentende tomar como destino (de los archivos de backup) una unidad de red, así que antes de continuar con los siguientes pasos tenemos que tener la carpeta destino ya compartida y con los permisos de escritura.

Continuando con el proceso tenemos que setear los parametros en la política para que pueda recuperar backups del tipo **_bare metal_** y el componente **_system state_**:

    $Policy | Add-WBBareMetalRecovery
    $Policy | Add-WBSystemState
    

Agrego los discos críticos como volúmenes para respaldar:

    $Volumes = Get-WBVolume -CriticalVolumes
    Add-WBVolume -Policy $Policy -Volume $Volumes
    

Defino el destino de los respaldos, en este caso voy a utilizar un recurso compartido de red (el servidor &#8220;Server&#8221; y la carpeta compartida &#8220;BKP&#8221;):

    $BackupLocation = New-WBBackupTarget -NetworkPath "\\Server\BKP" -Credential
    Add-WBBackupTarget -Policy $Policy -Target $BackupLocation
    

Defino la programación, en este ejemplo quiero que se realice en 10 minutos, por lo que agrego:

    Set-WBSchedule -Policy $Policy -Schedule ([datetime]::Now.AddMinutes(10))
    

Y por último me resta iniciar el trabajo

    Start-WBBackup -Policy $Policy
    

Ok, en 10 minutos comenzará a respaldar el servidor. Les dejo el bloque de código todo junto, comentado y agrego al inicio una parte lógica para que comprueba si la característica de Windows Backup está habilitada:


  
Saludos,