---
id: 800
title: 'PowerShell: Cómo instalar Windows a un VHD'
date: 2015-07-04T22:21:38+00:00
author: Victor Silva
layout: simple
guid: http://blog.victorsilva.com.uy/?p=800
permalink: /powershell-como-instalar-windows-a-un-vhd/
dsq_thread_id:
  - "4519251321"
categories:
  - PowerShell
  - Windows Server
tags:
  - Dism
  - Instalacion de SO
  - Mount-DiskImage
  - New-Partition
  - New-VHD
  - PowerShell
  - VHDX
  - VM
  - Windows Server
---
En PowerShell, cada ve que pensamos en automatizar cosas, se nos van ocurriendo otras cosas más complejas o interesantes.

Una cosa que siempre me pareció interesante es poder automatizar la creación e instalación de las máquinas virtuales. Nosotros usamos muchas MVs en laboratorios, pruebas, simulación de incidentes, etc. Es un proceso que repetimos bastante.

Entonces se me ocurrió ponerle cabeza a este proceso repetitivo.

Como ya habíamos hablado en un post anterior sobre como trabajar con Hyper-V ([enlace al post](http://blog.victorsilva.com.uy/powershell-hyper-v-tareas-basicas-ii/)), voy a evitar la parte de explicar los comandos a utilizar. Solo voy a detallar los que son nuevos:

Lo primero es, comprobar que desde donde estamos ejecutando el script es un host de Hyper-V, en caso de que no sea; que termine el script. En caso de que sea; que nos guarde el nombre de las VMs que ya existen.

    Function Install-SO {
    Param
    (
    [parameter(mandatory=$true)][ValidateNotNullOrEmpty()]$ISO,
    [parameter(mandatory=$true)][ValidateNotNullOrEmpty()]$VHDX,
    [parameter(mandatory=$true)][ValidateNotNullOrEmpty()]$SizeGB,
    [parameter(mandatory=$false)][ValidateNotNullOrEmpty()]$Index
    )
    

Con el bloque de código anterior, empezamos a definir la función que nos permitirá instalar Windows en un .VHDX. Declaramos los parámetros que vamos a necesitar mas adelante:

ISO &#8211; Donde se encuentra la ISO de instalación
  
VHDX &#8211; Donde se va a guardar (y con qué nombre) el .VHDX resultante
  
SizeGB &#8211; El tamaño de nuestro disco
  
Index &#8211; Es la opción de instalación

Quiero aclarar que el index, es la opción que elegimos al momento de instalar. Es decir, cuando insertamos un medio de instalación de, por ejemplo, Windows Server nos aparecen varias opciones: Standard, Standard Core, Datacenter, etc. Esas opciones tienen un número y podemos declararlo si lo conocemos. Como no todos saben cual es el index necesario, agregue unas líneas más de código para que nos imprima en pantalla las opciones y nos permita seleccionar la imagen que nos interesa.

    If($Index -eq $null){
        Mount-DiskImage -ImagePath $ISO
        $ISOImage = Get-DiskImage -ImagePath $ISO | Get-Volume
        $ISODrive = [string]$ISOImage.DriveLetter + ":"
        $IndexList = Get-WindowsImage -ImagePath $ISODrive\sources\install.wim
        $IndexList
        Dismount-DiskImage -ImagePath $ISO
        Write-Host "Seleccionar imagen (0 = Salir):" -NoNewline
        $Index = "-1"
        While($Index -eq "-1"){
            $Index = Read-host
            If ($Index -eq "0") {
                Write-Host "Terminando..."
                Exit
            }
        }
    }
    

En el bloque anterior indicamos que si no declaramos el parámetro **_index_** (o sea, es $null), ejecutemos lo que esta dentro de la condicional; que básicamente es &#8220;listar&#8221; las opciones de imagenes que trae la ISO para que podamos imprimirlas en consola y mediante la función _Read-Host_, ingresemos la opción correcta.

Esto es lo que se tendría que ver al seleccionar la ISO de Windows Server 2012 R2:

<img src="https://lh5.googleusercontent.com/-pb1YZYL_3tA/VZX0-I_FJeI/AAAAAAAAHCA/N-pNndZIObA/w470-h268-no/PS_Wim2VHD_1.png" width="470" height="268" class="alignnone" />

El resto del código es bastante claro:

    Mount-DiskImage -ImagePath $ISO
    $ISOImage = Get-DiskImage -ImagePath $ISO | Get-Volume
    $ISODrive = [string]$ISOImage.DriveLetter + ":"
    

Generamos el VHD.

    $VMDisk = New-VHD –Path $VHDX -SizeBytes $SizeGB
    Mount-DiskImage -ImagePath $VHDX
    $VHDDisk = Get-DiskImage -ImagePath $VHDX | Get-Disk
    $VHDDiskNumber = [string]$VHDDisk.Number
    

Creamos la partición.

    Initialize-Disk -Number $VHDDiskNumber -PartitionStyle MBR
    $VHDDrive = New-Partition -DiskNumber $VHDDiskNumber -UseMaximumSize -AssignDriveLetter -IsActive | Format-Volume -Confirm:$false
    $VHDVolume = [string]$VHDDrive.DriveLetter + ":"
    

Volcamos la imagen de la ISO al disco.

    Dism.exe /Apply-Image /ImageFile:$ISODrive\Sources\install.wim /index:$Index /ApplyDir:$VHDVolume\
    
    BCDBoot.exe $VHDVolume\Windows /s $VHDVolume /f BIOS
    
    Dismount-DiskImage -ImagePath $ISO
    Dismount-DiskImage -ImagePath $VHDX
    
    }
    

Ya finalizado, para ejecutar la función tendriamos la siguiente línea:

    Install-SO -VHDX C:\VMS\WS2012R2.vhdx -ISO C:\ISOS\WindowsServer2012R2.iso -SizeGB 42GB
    

Donde **C:\VMS\WS2012R2.vhdx** es la ruta en la que se va a guardar el disco con la instalación, **C:\ISOS\WindowsServer2012R2.iso** esla ruta donde se encuentra la imagen ISO y **42GB** el tamaño del disco.

Dejo toda lafunción compartida desde Gist:



Saludos,