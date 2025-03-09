---
title: 'Mapear un usuario de AD con Office 365'
date: 2015-12-21T01:31:44+00:00
author: Victor Silva
layout: post
permalink: /mapear-un-usuario-de-ad-con-office-365/
dsq_thread_id:
  - "4473143771"
categories:
  - Office 365
  - PowerShell
tags:
  - Merge
  - Office 365
  - PowerShell
  - sincronizar contraseña
  - Usuario de AD
---
La situación de hoy es la siguiente: Necesitamos mapear un usuario de AD con Office 365, teniendo ya configurado la sincronización de Active Directory con nuestra organización de Office 365. Básicamente tenemos que poder hacer un "
merge"
 de un usuario que tiene un buzón en Office 365 con un usuario de Active Directory.

## Situación

Por qué puede pasar éste problema? Porque algunas organizaciones primero empiezan trabajando con Office 365 y luego se deciden sincronizar las cuentas con el Active Directory de la empresa.

Es un grave error llegar a esta situación, ya que el usuario debe manejar, y gestionar, 2 cuentas diferentes; Office 365 y AD.

## Solución

Habiendo aclarado un poco en donde nos encontramos, empecemos a trabajar!

Lo primero que vamos a revisar, es que nuestro equipo cuente con el módulo de Active Directory para Azure (lo descargamos del siguiente [enlace](https://technet.microsoft.com/en-us/library/dn568015.aspx)). Teniendo el módulo correspondiente, vamos a ejecutar algunos comandos&#8230;

El primero es para obtener el **ObjectGUID** del usuario en cuestión. Ésta propiedad es una identificación única que nos permite establecer la "
fusión"
 de los usuarios. Para obtenerla, tenemos que ejecutar desde una consola cmd (con privilegios de administrador), o de PowerShell, en un controlador de dominio el siguiente comando:

    Ldifde –d “CN=xxx…,OU=xxx,DC=xxxx,DC=xx” –f C:\Users\Victor\Desktop\Usuario.txt
    

El archivo que se genera de la ejecución anterior, contiene las propiedades del usuario que queremos hacer sincronizar con Office 365.

El valor tiene un aspecto similar al siguiente: **_z3Xbu1xFBUapOeDqRNTR1E==_**

Ahora, primero nos conectamos a Office 365 desde la consola:

    $Cred = Get-Credential
    Connect-MsolService -Credential $cred
    

Ya conectados, vamos a ejecutar el comando que nos va a permitir mapear un usuario de AD con Office 365:

    Set-MsolUser -UserPrincipalName user1@victorsilva.com.uy -ImmutableId z3Xbu1xFBUapOeDqRNTR1E==
    

Luego de ejecutar el comando anterior, tenemos que forzar la sincronización de Active Directory con Office 365 desde el asistente y al finalizar el proceso, el usuario **_user1@victorsilva.com.uy_** va a poder iniciar sesión desde Office365 con la contraseña de Active Directory.