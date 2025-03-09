---
title: 'Skype for Business - Algunos usuarios no aparecen para habilitarlos'
date: 2015-07-19T21:04:13+00:00
author: Victor Silva
layout: post
permalink: /skype-for-business-algunos-usuarios-no-aparecen-para-habilitarlos/
dsq_thread_id:
  - "4488034410"
categories:
  - PowerShell
  - Skype for Business Server
tags:
  - Cmdlet
  - Habilitar usuarios
  - msRTCSIP-ArchivingEnabled
  - msRTCSIP-OptionFlags
  - msRTCSIP-PrimaryHomeServer
  - msRTCSIP-PrimaryUserAddress
  - Skype for Business
---
Días atrás al finalizar la instalación de Skype for Business y comenzar a habilitar los usuarios, encontré una situación que me llamó la atención:

Algunos usuarios no aparecían al buscarlos, desde el panel de control de Skype for Business.

<img src="https://lh3.googleusercontent.com/-oeAprlZXr40/Vag78Iu6ABI/AAAAAAAAHEw/Qkjsgewlyv4/w943-h577-no/SFB_Find_users_2.png" width="943" height="577" class="alignnone" />

Empecé a googlear este comportamiento y llegué a un post de **Terence Luk** ([enlace al post](http://terenceluk.blogspot.com/2011/12/unable-to-find-user-to-enable-for.html)) que me brindó la información que necesitaba.

Parece que si un usuario tiene valores asignados en alguno (o todos) de los siguientes atributos de Active Directory:

<img src="https://lh4.googleusercontent.com/-4ADlH_d-D-Y/Vag78Ccpm1I/AAAAAAAAHEs/xFNyZi3S-Rg/w449-h568-no/SFB_Find_users_1.png" width="449" height="568" class="alignnone" />

no aparecen en la búsqueda para habilitar los usuarios.

El amigo Terence, nos recomienda limpiar los valores de éstos atributos, y que mejor idea que hacerlo con **_PowerShell_**?

Por eso es que armé esta _mini-función-reducida_, que permite con solo ingresar el usuario en cuestión limpiar los atributos para que quede listo para integrarse a la nueva implementación :).

{% highlight posh%}
Function Clean-ADUsers {
  Param (
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Name
  )
  $user = Get-ADUser $Name
  $ldapDN = "LDAP://" + $user.distinguishedName
  $adUser = New-Object DirectoryServices.DirectoryEntry $ldapDN
  $adUser.PutEx(1, "msRTCSIP-PrimaryUserAddress", $null)
  $adUser.PutEx(1, "msRTCSIP-ArchivingEnabled", $null)
  $adUser.PutEx(1, "msRTCSIP-OptionFlags", $null)
  $adUser.PutEx(1, "msRTCSIP-PrimaryHomeServer", $null)
  $adUser.SetInfo()
}
{% endhighlight %}

Happy scripting!