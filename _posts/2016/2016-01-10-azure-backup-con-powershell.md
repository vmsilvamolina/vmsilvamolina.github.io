---
title: 'Azure Backup con PowerShell'
date: 2016-01-10T22:55:25+00:00
author: Victor Silva
layout: post
permalink: /azure-backup-con-powershell/
dsq_thread_id:
  - "4483035952"
categories:
  - Azure
  - PowerShell
tags:
  - Azure
  - Azure Backup
  - BackUp
  - Backup Offsite
  - PowerShell
---
Azure ofrece una extensa variedad de productos y servicios, que están ahí, para usarlos y conocerlos, probar si realmente es lo que estamos buscando para resolver nuestras necesidades, o no. Lo divertido es eso, evaluar las funcionalidades. Hoy quiero hablar de Azure Backup con PowerShell (como no podía ser de otra manera), ya que el backup off-site es, en algunos escenarios, un requerimiento fundamental.

## Requisitos

Para poder comenzar a trabajar con Azure Backup es necesario revisar que la versión de Windows PowerShell y de Azure PowerShell sea la correcta (que sea la mínima aceptable) para poder realizar la configuración que vamos a ver mas adelante.

### PowerShell

Para verificar la versión de PowerShell, vamos a ejecutar en nuestra consola:

    $PSVersionTable
    

Obteniendo como resultado, algo como lo siguiente:

<img src="https://lh3.googleusercontent.com/RW5oMixm_ZBY65lO9fkXE59lrCBoE4PbQJlI6yMzGDPXwbxrl6-8_g5DSxCYHCIVVtZWYCi9MHyqfkSf8PmozmO-9ivL8-PosxYcGQFApm4097O5TYTOJltqzdqTvwKeCXGx6RGVEV9bnZIsdzCMu0iC4kOP3Ox-1cX4sy3oj_OIK0hj2Oje09Tr1E54BrvySG98EeZN-pIhTGCWQqXRA2zHAdj9XWwQaa46yWQUn9P7VpFpEfOrQHXpUJvlpWihiNdRI-jUSe5xEmDXXpijkgwXr0xPhgN4HYVcFo7ooMOwmG3saym1rp3GfuXpxaKzI3mwvhfRtc_fwRFJX4_sF7r1_5X7VOT-l3hEiFysgztHDjoa1uu99zYeMwY8qIXHngq18bFOmHYkwu3HjpmbCuPJlhVafnqMjvqZ4EmdbAY0qTNkJP0iTaTkErvgNIDUvykIMsOwYJoXJL4ygRmBlPaypuRhksx4sbRB9UoDp5Tz2qxSx26pgz2u6Prmwv-hd9VEufgLz66Wen5OrAmuARlz0F-lLAbdCISVgCPn2WOQ8tfh3Jaow-61NNq26B6XQXni=w549-h308-no" width="549" height="308" alt="Azure Backup - Versión de PowerShell" class="alignnone" />

El valor de **PSVersion** tiene que ser mayor a 3.0. En caso de que sea una versión anterior, o quieran actualizar a la última versión a la fecha, les comparto el enlace para descargarlo: [WMF 5.0](https://www.microsoft.com/en-us/download/details.aspx?id=50395)

### Azure

Pueden ingresar al siguiente [enlace](http://azure.microsoft.com/pricing/free-trial/) para poder crear una suscripción trial de Azure, para los que no tengan acceso.

Ahora nos resta tener instalado el módulo Azure PowerShell en el equipo. La versión mínima es la 1.0, se puede acceder al mismo desde [éste enlace](https://github.com/Azure/azure-powershell/releases).

También ejecutando:

    Install-AzureRM
    

## Acceder a la suscripción y primeros pasos

Ejecutamos e ingresamos las credenciales que están asociadas a la suscripción que vamos a utilizar:

    Login-AzureRmAccount
    

<img src="https://lh3.googleusercontent.com/7MvA4ClxWomPlkmMGhyBhf_NN-nm3nDpsbVrcDU3kvzXyL82ZeKIYHd_CPODdOAS1LsanmPvOduA4yLGVJYFKH_mXPEKVUlbpnOzHr0698RYzYtLIbCw0sxjCz1Mo-SSxABOZWBSP4G6XPBl76oMCT3oQPBi09IoJl4aUIxCMBCuoGv47nVWh6hBFJnKN_e_FgfoKQIGzxg9vlrQHAU7ut7d-B8hESMqkhLjkDohVzLd5lR-HVJxwZztEHnrrrc7tmywAaqFTqDApLnkAhRBaMQD7zwOZG1-0_xTgRYFUmaqAM8HB4yuuH3y6jCIO1xEJcA6f-fBX8i2TtfXcnHoSaGXjQO03RNdEi2mFXcRvpv9UBJvrhZf4U2AoTivLJTdPNzCobBgyrYoUb7MZY0h20uiiJdMyAdoNtwY3gCmXxjLySMjFrKDGSMqJSG7xSCHOJs-UhQhau-iY0B70M1SfVMK-V_EGqogwJSrjyLZq3wSJRkCWLwnru5uelRKj3BzDK2Ls8fffzIvvELncxwtV4GbcZ9pd_TIP5eSAwPGG2NIlzh-fasY9HoFlxyJ4SxBUCQR=w568-h541-no" width="568" height="541" alt="Credenciales para Azure" class="alignnone" />

En caso de tener varias suscripciones asociadas a las credenciales ingresadas, vamos a recolectar los datos de la suscripción que vamos a utilizar ejecutando:

    Get-AzureRmSubscription
    

Prestarle atención al campo **_SubscriptionName_** que es el que vamos a usar para identificar la suscripción en los siguientes cmdlets, en mi ejemplo yo modifiqué el valor por el nombre de mi suscripción:

    $Subscription = "Visual Studio Enterprise con MSDN"
    Select-AzureRmSubscription -SubscriptionName $Subscription -Current
    

_(Ejecutar el bloque anterior solamente si tenemos varias suscripciones asociadas a las mismas credenciales)_

    Register-AzureRmResourceProvider -ProviderNamespace "Microsoft.Backup"
    New-AzureRmResourceGroup –Name “AzureBackup” -Location "West US"
    $BackupVault = New-AzureRmBackupVault -ResourceGroupName “AzureBackup” -Name “AzureBackupVault” -Region “West US” -Storage GeoRedundant
    

## Instalar el Azure Backup agent

Después de haber ejecutado el comando anterior, vamos descargar el agente desde el siguiente [enlace](http://aka.ms/azurebackup_agent) y luego de que finalice la descarga ejecutar como administrador:

    .\MARSAgentInstaller.exe /q
    

O simplemente ejecutarlo y acceder al entorno gráfico. La instalación basicamente es siguiente, siguiente, etc.

## Registrarse contra el servicio de Azure Backup

    $CredsPath = 'C:\'
    $CredsFilename = Get-AzureRMBackupVaultCredentials -Vault $BackupVault -TargetLocation $CredsPath
    $CredsFilename
    

Registrar la maquina contra el _vault_, usando el cmdlet Start-OBRegistration Import-Module MSOnlineBackup

    $Cred = $CredsPath + $CredsFilename
    Start-OBRegistration -VaultCredentials $Cred -Confirm:$false
    

## Configuración de Networking

    Set-OBMachineSetting -NoProxy
    Set-OBMachineSetting -NoThrottle
    

<img src="https://lh3.googleusercontent.com/eDMVuYhqfKSeftmioSlqQH6aRIHYBN8Fy5NpoChNQgM1LAbptERMoCMFIp14RLgZ4D-QrayuZvCqX7j6yBkABeQ81sSOmlU6hDSaPqyjoqgosd4UcaRz7ieOhipaEvrEPTJkZZRMteuaGrTS8Vhp-ggObcKqJj2oOiira5DU8WONm9CGKkYndbs0grmDNNnrHLG2IjkX6v3HWAr_hyZjMeNL7kRLcS_BN8Adxg0Szm9N23BLHaaEubtZYFBy2fyoBMtWLA81EY2IrknTG7V4JYAitx2_I4ZbQRldfdAt6c73K5FdKbo5TD2UooaP4pWUWDtJ-VICJZqoSAkklpKYmVGSUC7BZ-ON9Ucp2hmxIogDSkNUx8QvHhgjYk8FuNV8-GvAD2gcXQyNA_f8DHjPKssQMzvZvSTnIDQU8A_SNotkZHdoHZKP3GPhj_CmlJkgQiikgwBlsg9G-x9AfBoRkMMcpaXiS123NEsZ_i7q1wife3kNnTQKLgYSaPLtu3LHFC1gLHa-aapiWLyqcVNRgTfJlJbuPUhLGc7pQ6dekNTzDsffc5QpQUglv4c_v3mIAwa3=w895-h575-no" width="895" height="575" alt="Comandos ejecutados en PowerShell" class="alignnone" />

## Seguridad

Para otorgar una mayor medida de seguridad, se debe definir una **_passphrase_**, que realiza la encriptación de los datos, para ello debemos ejecutar:

    ConvertTo-SecureString -String "P@ssw0rd.S3cur3.2016" -AsPlainText -Force | Set-OBMachineSetting
    

# Respaldo

Todos los backups están governados por una política, que consta de tres partes fundamentales:

**BackUp schedule** - Se define el período en el que se ejecuta la sincronización **Retention schedule** - Define el tiempo que se va a mantener un punto de restauración **File inclusion/exclusion specification** - Determina que archivos (o carpetas) se van a respaldar

Para crear la política que vamos a utilizar, ejecutamos:

    $NewPolicy = New-OBPolicy
    

### Schedule

    $Sched = New-OBSchedule -DaysofWeek Friday, Sunday -TimesofDay 21:00
    

Se pueden configurar varios días de la semana, o todos. En cambio, solamente podemos definir hasta 3 horarios diferentes para que se ejecute la sincronización. En este ejemplo, dejamos que se ejecute los Viernes y Domingos a las 21:00hs.

Para que lo anterior funcione, debemos asociar el **schedule** con una **policy**:

    Set-OBSchedule -Policy $NewPolicy -Schedule $Sched
    

### Retention policy

Como en la parte anterior, ahora nos toca definir el tiempo de retención de los puntos de restauración, para este ejemplo vamos a dejar 5 puntos y vamos a asociar la configuración a la política que ya tenemos creada para este fin:

    $RetentionPolicy = New-OBRetentionPolicy -RetentionDays 5
    Set-OBRetentionPolicy -Policy $NewPolicy -RetentionPolicy $RetentionPolicy
    

### Archivos a respaldar

El objeto _OBFileSpec_ define que archivos son incluídos y cuales son excluídos.

Ahora vamos a declarar los archivos incluídos y los excluídos, y finalmente agregarlos a la política:

    $Inclusions = New-OBFileSpec -FileSpec @("C:\", "D:\")
    $Exclusions = New-OBFileSpec -FileSpec @("C:\windows", "C:\temp") -Exclude
    Add-OBFileSpec -Policy $newpolicy -FileSpec $Inclusions
    Add-OBFileSpec -Policy $newpolicy -FileSpec $Exclusions
    

### Aplicar la política

Ya teniendo todo definido, nos resta aplicar la política ejecutando lo siguiente:

    Set-OBPolicy -Policy $newpolicy
    

Luego de ejecutar lo anterior, vamos a tener que indicar que sí queremos hacer el respaldo en Azure.

Y eso es todo, ya tenemos configurado nuestro respaldo en Azure!!! Y toda la configuración hecha por consola 🙂

Podemos obtener información del estado de la política utilizando los siguientes comandos:

    Get-OBPolicy | Get-OBSchedule
    Get-OBPolicy | Get-OBRetentionPolicy
    Get-OBPolicy | Get-OBFileSpec
    

En próximas entregas vamos a ver como manipular estos respaldos y como restaurar de un punto guardado en Azure.

Saludos,