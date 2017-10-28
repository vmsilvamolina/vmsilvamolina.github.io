---
id: 478
title: 'PowerShell &#8211; Como trabajar con el registro de Windows'
date: 2014-09-01T20:57:18+00:00
author: Victor Silva
layout: post
guid: http://blog.victorsilva.com.uy/?p=478
permalink: /powershell-como-trabajar-con-el-registro-de-windows/
dsq_thread_id:
  - "4472450908"
categories:
  - PowerShell
tags:
  - Cmdlets
  - HKLM
  - PowerShell
  - Registro de Windows
  - Registry
---
Si trabajamos con Software y mas que nada si trabajamos desde la parte de administración, en algún momento vamos a tener que trabajar con claves de registro. Ya sea para corroborar que existe y está creada, o que necesitemos asignarle un valor en particular, o directamente eliminarla. Así que vamos a ver como podemos manipular estas claves de registro desde nuestro querido PowerShell.<!--more-->

Una manera muy fácil y entendible que tenemos para poder trabajar con el Registro de Windows es de la siguiente manera:

<pre class="lang:ps decode:true">$RegPath = 'HKEY_LOCAL_MACHINESOFTWAREMicrosoftWindowsCurrentVersion'
$Key = Get-ItemProperty -Path "Registry::$RegPath"</pre>

Con estas simples lineas de codigo, podemos trabajar con nuestro registro. Solamente, basta con sustituir el valor de _$RegPath_ con cualquier ruta de la clave del Registro.

Si este código lo pegamos en el editor ISE, escribimos la variable $Key seguida de un punto, la funcionalidad IntelliSense mostrará todas las propiedades de esta clave, para poder manipularla sin tener que escribir de más. Para seleccionar la propiedad que necesitamos, basta con pulsar la tecla TAB luego del &#8220;.&#8221; para ver los valores diponibles.

Luego de ver esta manera, vamos a describir otra manera mas fácil todavía:

<pre class="lang:ps decode:true ">Get-ItemProperty HKLM:SoftwareMicrosoftWindowsCurrentVersion</pre>

Debemos considerar que la sigla HKLM significa HKEY\_LOCAL\_MACHINE. Por lo que si queremos utilizar el registro para el usuario actual la sigla sería HKCU (HKEY\_CURRENT\_USER).

Así si queremos por ejemplo desplegar el valor de la clave _ProgramFilesDir_ debemos escribir:

<pre class="lang:ps decode:true ">Get-ItemProperty -Path HKLM:SoftwareMicrosoftWindowsCurrentVersion -Name ProgramFilesDir</pre>

En caso de querer agregar una entrada de registro, debemos ejecutar:

<pre class="lang:ps decode:true">New-ItemProperty -Path HKLM:SOFTWAREMicrosoftWindowsCurrentVersion -Name PowerShellPath -PropertyType String -Value $PSHome
</pre>

Con el comando anterior, agregamos la clave **PowerShellPath**, con el tipo de dato **string** y de valor la variable **$PSHome**. Si la clave existe podemos utilizar el parametro _Force_ para reescribir el valor.

Si la idea eliminar la entrada del registro, es bastante parecido salvo que el comando es _**Remove-ItemProperty**_

<pre class="lang:ps decode:true ">Remove-ItemProperty -Path HKLM:SOFTWAREMicrosoftWindowsCurrentVersion -Name PowerShellPath</pre>

Saludos,