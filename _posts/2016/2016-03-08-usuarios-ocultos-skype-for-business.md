---
title: Usuarios ocultos en Skype for Business
date: 2016-03-08T19:43:29+00:00
author: Victor Silva
layout: post
permalink: /usuarios-ocultos-skype-for-business/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"c97a3f3773ad";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:85:"https://medium.com/@vmsilvamolina/usuarios-ocultos-en-skype-for-business-c97a3f3773ad";}'
dsq_thread_id:
  - "4720497167"
categories:
  - PowerShell
  - Skype for Business Server
tags:
  - Habilitar usuarios en Lync
  - Habilitar usuarios en Skype for Business
  - PowerShell
  - Skype for Business Server
---
Hoy quiero compartir algo que hace un tiempo tuve que resolver una situación en particular: Habilitar usuarios ocultos en Skype for Business.

Por qué habilitar? Porque a simple vista estos usuarios no existían. Es decir, al intentar habilitarlos en el Panel de Control de Skype for Business, no aparecían en las busquedas. Era como si los hubieran eliminados de Active Directory.

Luego de buscar información por un rato, me comentan que ellos habían realizado un piloto con Lync Server 2010. Y adivinen que usuarios participaron de ese piloto? Los mismos que no aparecían en la nueva implementación!

Empece a revisar los atributos de Active Directory y encontré varios cambios que estaban siendo utilizados con información y configuración que no era la actual.

Es por ello que quiero compartir una pequeña función para poder "
habilitar"
 (o limpiar) esos usuarios para las nuevas implementaciones:

    Function Clean-SFBUsers {
        <#
        .SYNOPSIS
            Este Cmdlet permite borrar los valores de los atributos que usa Skype for Business/Lync Server
            en un usuario (o varios) de la organización.
        .EXAMPLE
            Clean-SFBUsers -User 'vsilva'
            Con el ejemplo anterior, todos los atributos de la indentidad 'vsilva'
            que estén con información pasarán a quedar de forma predeterminada sin valores asignados.
        .PARAMETER User
            Identidad a la que se pretende modificar los atributos.
        #>
        param (
          [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$User
        )
        process {
          $adUser = Get-ADUser $User
          $ldapDN = "LDAP://" + $adUser.distinguishedName
          $userObject = New-Object DirectoryServices.DirectoryEntry $ldapDN
          $userObject.PutEx(1, "msRTCSIP-UserEnabled", $null)
          $userObject.PutEx(1, "msRTCSIP-PrimaryHomeServer", $null)
          $userObject.PutEx(1, "msRTCSIP-PrimaryUserAddress", $null)
          $userObject.PutEx(1, "msRTCSIP-ArchivingEnabled", $null)
          $userObject.PutEx(1, "msRTCSIP-OptionFlags", $null)
          $userObject.PutEx(1, "msRTCSIP-DeploymentLocator", $null)
          $userObject.PutEx(1, "msRTCSIP-UserPolicies", $null)
          $userObject.PutEx(1, "msRTCSIP-FederationEnabled", $null)
          $userObject.PutEx(1, "msRTCSIP-InternetAccessEnabled", $null)
          $adUser.SetInfo()
        }
    }
    

Con ésta función vamos a poder limpiar toda la basura en los atributos que son utilizados para Skype for Business 2015.

Saludos,