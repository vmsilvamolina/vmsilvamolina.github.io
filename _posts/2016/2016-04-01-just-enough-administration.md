---
title: Just Enough Administration
date: 2016-04-01T01:54:52+00:00
author: Victor Silva
layout: post
permalink: /just-enough-administration/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"49dfaf0fb1c5";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:73:"https://medium.com/@vmsilvamolina/just-enough-administration-49dfaf0fb1c5";}'
dsq_thread_id:
  - "4734362467"
categories:
  - DevOps
  - PowerShell
tags:
  - JEA
  - Just Enough Administration
  - PowerShell
  - PowerShell RBAC
  - RBAC
---
Just Enough Administration (JEA) proporciona una plataforma _Role Based Access Control (RBAC)_ a través de PowerShell. Permite a usuarios concretos realizar tareas administrativas específicas en los servidores sin darles derechos de administrador. Esto permite llenar los vacíos entre soluciones de RBAC existentes, y simplifica la administración a la hora de delegar permisos.

### Requisitos

Si bien _Just Enough Administration_ es parte de PowerShell, es neecsario cumplir con ciertos requerimientos que voy a pasar a detallar:

## Infraestructura

Para poder hacer uso de JEA, es necesario contar con lo siguiente:

  * Una instancia de Windows Server 2016 TP4 o Windows Server 2012 R2 con WMF 5.0 RTM
  * Tener permisos de administrador sobre el servidor anterior
  * El servidor debe estar unido a un dominio

A su vez es necesario tener habilitado **[PowerShell Remoting](https://technet.microsoft.com/en-us/library/hh849694.aspx)**; para cumplir con lo anterior debemos ejecutar simplemente:

    Enable-PSRemoting
    

<img src="https://lh3.googleusercontent.com/va-KQLLqvPwqgErSFn6y55E1K1IIXrHdVpxfnp__hef4lSpzGtamEyHDyBB6KGG8BJgInaSXxmA8PEtT2FCtVurEadYLKZNd-XFtI4Iu84OUvm-LBnkadx0B8pkPrKN6_gKyKbs6Ac8BhAET6IgVETFyITjksLv02X_AoWgGdV1o2HXJLQulZXq4nxg0S2BDH8zi6iVYwu1wC2ZtJTgb5_p7fZVtp2raDbf0c7GijfuHXrDUFK6F3Bfs-ovEEbQ6hcvCS28j7EfIUOhxmglZPyZmEAjbE8PfKuzGrA0u_67j3EHZBhYcB4R7A9xRlRuRX13XherVlXIPiXnqN-GA9GiMTz_2TgYdAAMsjrksOXk2fjj0-oLrfzZTtJSFtW7MlDPZV0kQGPp1vigbtcFPve-ZOoNYjq7Epx5kEgaSaW7l65b9bnK_HBkr4x1AFYApC3rVtb_xDpVsiLdaP4x_mN3mU2_XkN53YJf7Rrdr8A42s2bVLioc1pwedDZEOxn8zSTIELLk77pJL1srC9gqBItcOtC9eXZbqD2c767yMINPglTf8o36TVA6qIFrGATmqQA5=w688-h280-no" width="688" height="280" alt="Just Enough Administration" class="alignnone" />

## Difinimos la capacidad del rol

Con el siguiente bloque de código vamos a crear el archivo que va a usarse para limitar el scope de comandos al que puede acceder el rol definido, así como también se define un Cmdlet custom (Get-UserInfo):

    $powerShellPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0" 
    
    # Campos en el archivo
    $MaintenanceRoleCapabilityCreationParams = @{
        Author =
            "Victor Silva"
        ModulesToImport=
            "Microsoft.PowerShell.Core"
        VisibleCmdlets=
            "Restart-Service"
        CompanyName=
            "vmsilvamolina"
        FunctionDefinitions = @{ Name = 'Get-UserInfo'; ScriptBlock = {$PSSenderInfo}}
            }
    
    # Creamos el modulo demo, que va a contener el archivo Role Capability
    New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\Demo_Module" -ItemType Directory
    New-ModuleManifest -Path "$env:ProgramFiles\WindowsPowerShell\Modules\Demo_Module\Demo_Module.psd1"
    New-Item -Path “$env:ProgramFiles\WindowsPowerShell\Modules\Demo_Module\RoleCapabilities” -ItemType Directory 
    
    # Creamos el archivo Role Capability
    New-PSRoleCapabilityFile -Path "$env:ProgramFiles\WindowsPowerShell\Modules\Demo_Module\RoleCapabilities\Maintenance.psrc" @MaintenanceRoleCapabilityCreationParams
    

## Configuración para el ejemplo

Vamos a definir la configuración de la sesión para que cuando inicie el usuario en cuestión (en el ejemplo se llama Usuario) ya tenga el rol configurado y solo le permita acceder a los Cmdlet que definimos en el archivo _Maintenance.psrc_. Con el siguiente bloque de código integramos la configuración permitida al usuario con el usuario de dominio:

    $domain = (Get-CimInstance -ClassName Win32_ComputerSystem).Domain
    
    #Reemplazar con el grupo o usuario a usar en el ejemplo
    $NonAdministrator = "$domain\Usuario"
    
    $JEAConfigParams = @{
            SessionType= "RestrictedRemoteServer" 
            RunAsVirtualAccount = $true
            RoleDefinitions = @{ $NonAdministrator = @{RoleCapabilities = 'Maintenance'}}
            TranscriptDirectory = "$env:ProgramData\JEAConfiguration\Transcripts”
            }     
    if(-not (Test-Path "$env:ProgramData\JEAConfiguration")) {
        New-Item -Path "$env:ProgramData\JEAConfiguration” -ItemType Directory
    }
    $sessionName = "JEA_Demo"
    if(Get-PSSessionConfiguration -Name $sessionName -ErrorAction SilentlyContinue) {
        Unregister-PSSessionConfiguration -Name $sessionName -ErrorAction Stop
    }
    New-PSSessionConfigurationFile -Path "$env:ProgramData\JEAConfiguration\JEADemo.pssc" @JEAConfigParams
    
    Register-PSSessionConfiguration -Name $sessionName -Path "$env:ProgramData\JEAConfiguration\JEADemo.pssc"
    Restart-Service WinRM
    

<img src="https://lh3.googleusercontent.com/-Gt6ysunT-9DvlEHAVIPV5Nx8WeJBbfAm2ALx_1XRKXCSnXGY0lKY2JfkvMptV7VCfaIU679p9Xl5lN1NfIScUXJ4FkeUjivGdmZBciuQJxPhM4MkuMI0t1ot4o5IwGIUDZFle954BN-2dReR_3I9XUzPNuW9aotgOz-V9RA50qIIuk-rKwuo8TKOBx850FgH-_ZFBnASpKl-4oqdj9XtGULH5De_lOdFg5agbVbXp1Wiz5hCvayjHmWYJOHgA_yfWkTd8BwLks7c6zagAzkB9lvs6r5XZ3_Z8SeZjjlJFxhpxHK3YvehmvqkeVGb4gDs3ZmgSKdLTXxJlzVCsc34GKbS2o_mER37T57aLk50WzV7vdC--k10PGpEnypIDjvfIMfsLlpFCr7_hUv8OQt7AYmP2woQIa0l--fswFf0JJqktc780vJAiX_OU-74P_UxBOjhqVOxqTEXCGwIdDQeEmsnKhtLZXX5DaxGUd41IrBInVqcDNP-dl1rJjDuS76gUUHmX_JA9tJPFpVifmeuo2g75oHF97HHSdC-DkDn3il5TGDrYhL9fUed0qTMgeJdIy6=w873-h398-no" width="873" height="398" alt="Creando la configuración de JEA" class="alignnone" />

### Usando JEA con un usuario que no es administrador

Para demostrar JEA en acción, vamos a necesitar usar PowerShell remoto como un usuario "
no-administrador"
. Para realizar esta acción hay que definir un usuario con el siguiente código:

    $NonAdminCred = Get-Credential
    

Ingresar las credenciales de la cuenta sin permisos de administrador cuando lo solicite. Luego, ingresar a una sesión remota usando el archivo de configuración creado y las credenciales guardadas:

    Enter-PSSession -ComputerName . -ConfigurationName JEA_Demo -Credential $NonAdminCred
    

Si prestan atención, el prompt cambió ya que nos encontramos dentro de la sesión con el usuario "
no-administrador"
. Ahora, vamos a ejecutar el Cmdlet:

    Get-Command
    

<img src="https://lh3.googleusercontent.com/F00Be-FbfG37_HAtywvPwIU1YPnoS3CzKsV_YlJh82VqSKsxVwdPmP6NXAqbrsQ7uo9rCtlx5PjITtcCLlVngwpUpzHZGpLjqCobBW_oWV_t5my_s1qCjpVWNUsNYq7XBP1HBZvjeh72vtJOidjqSQPLWWtyiP58-3W5yiI7hO5gfNWtAkIud8ggEdL2Id17UXiu08kG-XJV3G1SUI2VT6guX0CttfK60Swsx4ZN1S4d5jIhh8ZsgYnTMi5WJCObwIJ_xxLkILVJ5gQdUEdtVG_yfHkLJGowYySxo9Tt26c1p77ewykPYA4b8i0Vlq05s2TQ19AMpFZPblGhMh8ug4f7I8hDvhd_rejBILBKoMQex_v8MsW_LofiYt6ovu3HWnLXeBvzRTy1qydfKbfxoFKbanU5Mp8QcpDnpIKlWYheFP0ci_lqv2XfZfOg9HprWANBLBUm33k0tYOg2AQsrZnKK-0P5F7hJ_x4X9957Ys-gSPWBc5T8Q_tWi0wJ_wJBOWu6Iqu67TG81WPIhxMwDXFCwR2q1wr-xqSTlE9y43vFKY5BDg3Ablj_SgTM7WzZwsH=w874-h335-no" width="874" height="335" alt="Sesión iniciada y Get-Command" class="alignnone" />

El Cmdlet anterio muestra la lista de todos los comandos disponibles para ejecutar en la sesión. Para los que conocen este Cmdlet, en ocasiones normales, la lista es muy superior a la que nos muestra en este escenario, debido a las restricciones ya aplicadas al usuario que estamos usando.

En este punto, vamos a ejecutar un comando:

    Get-UserInfo
    

<img src="https://lh3.googleusercontent.com/x1MIviFVOw3XOVxkhi-gOkAN5yAt-GDxP_gGmYpeRswoMaKEICHcKQMkcCSPsU6Ysyq2cNsAsp9JYz_LBQqjGWtH1Uff3GsvNoqV6ZcWzjU7pSd_3iReaGld47GEtY_i0DDT6jY5SnYp1hsubQm931j2KI0M3gMB9SgtIADE3VeerH4xjf41OeE9MgS04Sz5YulAj7riUyDR4lBaP74dZ_ZLa5dE1AEjgEbB0ggAvswXmhCKtDVFx8paYkML7w0zuHatY4gUnlTi-VfcJi4A1C0PvwY_3zwHad43AE_r9fzZPLMmx_yP3Rn1SiSRnHWdqv8iWsUAgpt8hhHBIKPw75rTNDdFXZS-mARszjS-Cqs_2mdJRx1gKFTxG3HVyDj5aS4iBLE4FrTYsUhVbBROq-dgWfeZoLOpNvT-5KtjSr2qu8TDEwjE3P6q_OaCw5K5rovpFZa5oSIqY8Buj76Zhh19Ugm0M806asIDrGW66iL1UXYuYjbBzzifD6nQVmVsTNX44F3gZ9J1ubildZlI-IdyDNI96UedBgq4KbAfjGGCujnv9rcz5QZxJyaObe6vrCTM=w658-h169-no" width="658" height="169" alt="Get-UserInfo" class="alignnone" />

Este Cmdlet custom, muestra el "
ConnectedUser"
 como si fuera "
RunAsUser"
. El _ConnectedUser_ es la cuenta de dominio connectada a la sesión remota que no tiene privilegios. La cuenta "
Run As"
 es la que realiza las acciones con privilegios. Ahora usando los permisos concedidos en la sesión vamos a ejecutar el Cmdlet _Restart-Service_:

    Restart-Service -Name Spooler -Verbose
    

Ya que este comando es uno de los que aparece en la lista de configuración. Normalmente, este Cmdlet requiere privilegios de administrador para ejecutarse.

Como último paso vamos a ejecutar un comando que no aparece en la lista (cuando ejecutamos el Get-Command), por ejemplo:

    Restart-Computer
    

<img src="https://lh3.googleusercontent.com/JaEFLSYsnVmzM7OKtYQhf0ptjHfO0KxK1N0NWmhAq-KPdJAfNuPdorZqHu0BSyS05qWu7p5vVjhASAPyOcoBeeDGqm4KMV0nY_hstSaqlMK8aNil0u_i1vNsFlSmXN3Xe-yfMOH1PoqZWZywC9SFKyiqMAAuVdj6jPwZ-DxBjy3vWCxyDlsTDCBbLP0bBjEnkijpIzhIoK9-eXKrxxG4uk3z-P78sLSwUormbxkgj1IiL0o679LsD1jFU1qesr7yNnfqR951Fpmj4cfrmf5MvBTiBC2LKZ2vdoWKyKSGKPVpqX8J28vPXRTIh9SrMBBxv9alFIXD5afTTZtAsRETQWyfEkvem-nwNsHGKWTmSK6alc1o-fw6bmoIlr0WxtWRjaU4s2EHRCXSCyK1legeyvwtLmkIYqWveMv4PgLFI5agRjqlEoMBoUmrK2uhkCUPsZBebp9VFRZVyTazh2GpzE-YQ3hx8wpcAaomkhGg_BaC4zsmkjcZFqWXp7WkzOkGMlNIs7OTu-6dJxeRgZ_H7Hp7ao1Fi7RWN4ALS7yf6cpMQWykmKa4RDfbCY7V9kzH50uA=w875-h322-no" width="875" height="322" alt="Restricción de JEA" class="alignnone" />

JEA restringe los comandos que necesitan privilegios y que no son declarados dentro de la configuración aplicada. Por eso nos genera el error al intentar ejecutar el comando _Restart-Computer_.

Para cerrar la sesión del usuario vamos a ejecutar:

    Exit-PSSession
    

Y listo! Así vimos un ejemplo de como usar JEA para proporcionar acceso basado en roles.

Saludos,