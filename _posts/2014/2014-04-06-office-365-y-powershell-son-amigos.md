---
title: 'Office 365 y Powershell... son amigos!'
date: 2014-04-06T18:25:33+00:00
author: Victor Silva
layout: post
permalink: /office-365-y-powershell-son-amigos/
dsq_thread_id:
  - "4471578414"
categories:
  - Office 365
  - PowerShell
tags:
  - Cmdlets
  - Exchange Online
  - Office 365
  - PowerShell
  - Script
---
**Editado: 13/4/2015**

A la persona que le ha tocado administrar Office 365 alguna vez, de seguro tuvo que hacer alguna tarea desde PowerShell. También estoy seguro que las primeras veces, nos parece bastante incomodo, mas que nada la manera de iniciar sesión. Hoy voy a tratar de demostrar que Office 365 y PowerShell son amigos, tratando de automatizar y simplificar algunas tareas.

## Inicio de sesión

La primer tarea y creo la mas engorrosa, si no se tiene algo mas "automático", es la de iniciar sesión.

Necesitamos descargar: [Microsoft Online Services Sign-In Assistant](http://www.microsoft.com/en-us/download/details.aspx?id=41950)

Luego vamos a abrir la Windows PowerShell ISE o el bloc de notas y vamos a pegar el siguiente código:

{% highlight posh %}
#Importar el módulo
Import-Module MSOnline

#Declarar las credenciales del admin
$user = "nombre@dominio.com"

#Se abre un cuadro de diálogo y solicita su contraseña
$cred = Get-Credential -Credential $user

#Conecta con el servicio de Office 365
Connect-MsolService -Credential $cred

#Establece una sesión remota de PowerShell para intercambio en línea
$msoExchangeURL = “https://ps.outlook.com/powershell/”

#Importa la sesión de Powershell localmente
$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $msoExchangeURL -Credential $cred -Authentication Basic -AllowRedirection

Import-PSSession $session
{% endhighlight %}

Guardamos el archivo con el nombre, por ejemplo, **Login365.ps1**.En mi caso el **Login365.ps1** lo guarde en la carpeta **c:\powershell\Login365.ps1** Iniciamos la consola en modo administrador y ejecutamos lo siguiente (cada línea es un comando a ejecutar):

{% highlight posh %}
cd / 
cd .powershell
.\Login365.ps1
{% endhighlight %}

Nos va a aparecer una ventana, ya con el correo que escribimos antes, solo resta agregar la contraseña y aceptamos. A partir de este momento estamos conectados a Office 365 por medio de powershell.

## Comandos disponibles

Una de las cosas que mas nos molestan es la falta de información al tratar de realizar tareas, por lo que la segunda tarea en la administración va a ser conocer los comandos disponibles que tenemos. El comando que nos hace este favor es:

{% highlight posh %}
Get-Command -module MSonline
{% endhighlight %}

Para obtener mas ayuda sobre un comando en particular ejecutar:

{% highlight posh %}
Get-Help <nombreDelComando> -detailed
{% endhighlight %}

## Ver suscripciones disponibles

Existe un comando que permite ver las suscripciones existentes en la organización y las cantidad de licencias que posee. El comando en concreto es:

{% highlight posh %}
Get-MsolSubscription
{% endhighlight %}

## Usuarios con Licencias asignadas

Otra información necesaria es poder ver los usuarios de la organización que cuentan con una licencia asignada. Para poder comprobar el estado, basta con ejecutar el siguiente comando:

{% highlight posh %}
Get-MsolUser * | Where-Object {$_.isLicensed - eq "TRUE"}
{% endhighlight %}

Y si queremos ver dentro de muchos usuarios los que no tengan licencia asignada? Muy parecido&#8230; Basta con cambiar el valor "TRUE" a "FALSE", quedando de la siguiente manera:

{% highlight posh %}
Get-MsolUser * | Where-Object {$_.isLicensed - eq "FALSE"}
{% endhighlight %}

## Contraseña nunca expira

La contraseña de los usuarios siempre es un tema a tratar. Una de las cosas que podemos ver con Office 365 es la posibilidad de que la contraseña nunca expire, si bien no es del todo recomendable por temas de seguridad, no esta mal tener en cuenta cual es el procedimiento correcto para realizarlo. SI queremos hacer este cambio para todos los usuarios de la organización, deberemos ejecutar lo siguiente:

{% highlight posh %}
Get-MSOLUser | Set-MsolUser -PasswordNeverExpires $true
{% endhighlight %}

Para el caso de que solamente querramos hacer este cambio en algunos usuarios en particular, basta con ejecutar:

{% highlight posh %}
Set-MsolUser -UserPrincipalName vsilva@dominio.com -PasswordNeverExpires $true
{% endhighlight %}

¿Y que pasa si quiero ver que usuarios tienen como característica habilitada la contraseña nunca expira? Fácil:

{% highlight posh %}
Get-MSOLUser | Select UserPrincipalName, PasswordNeverExpires
{% endhighlight %}

Happy scripting!