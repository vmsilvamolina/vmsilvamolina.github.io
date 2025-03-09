---
title: 'PowerShell y Office 365 - Script para comprobar disponibilidad de dominio'
date: 2015-02-03T19:46:16+00:00
author: Victor Silva
layout: post
permalink: /comprobar-disponibilidad-de-dominio/
dsq_thread_id:
  - "4552077371"
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"b911d6a0d6e3";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:118:"https://medium.com/@vmsilvamolina/powershell-y-office-365-script-para-comprobar-disponibilidad-de-dominio-b911d6a0d6e3";}'
categories:
  - Office 365
  - PowerShell
tags:
  - Chequear dominio
  - Cmdlets
  - Disponibilidad de dominio en Office 365
  - PowerShell
---
A veces para poder crear algo interesante basta con mezclar cosas que no consideramos de primera como una opción valida. A mi me paso algo así cuando se me ocurrió este script.

Hace un tiempo habíamos hablado del comando Invoke-WebRequest. Y leyendo por internet encontré información sobre los dominios de Office 365.

En un artículo de la MSDN, nos comparten que que en caso de haber un dominio registrado ya, en office 365. Existen metadatos de federación que se generan de manera automática (mayor info en este [enlace](https://msdn.microsoft.com/library/azure/dn195592.aspx)). POr lo que si pensamos en un dominio el cual ya está registrado si ingresaramos a la siguiente dirección:

**_https://login.windows.net/%3CTenantDomainName%3E/FederationMetadata/2007-06/FederationMetadata.xml_**

Cambiando la etiqueta TenantDomainName por el nombre de dominio de tercer nivel a corroborar,por ejemplo contoso. Si ya se encuentra registrado nos tiene que devolver un .XML, en caso de que no este registrado (dominio todavía disponible) debe devolver un error 404.

Para aclarar mejor un ejemplo, si quiero chequear el dominio fabrikam, debo ingresar la dirección:

**_https://login.windows.net/fabrikam.onmicrosoft.com/FederationMetadata/2007-06/FederationMetadata.xml_**

Ya que el .onmicrosoft.com es para todos los dominios de Office 365.

Ahora bien, sabiendo esto y recordando un viejo Cmdlets (Invoke-WebRequest) se me ocurrio armar un formulario que haga esto por mí, para comprobar la disponibilidad de los dominios.

El cuerpo del script está compuesto por el código a continuación:

{% highlight posh %}
###############################################################################
#
#  Office365DomainCheck - Victor Silva - 3/2/15
#
###############################################################################

#Cargo las librerias de .Net
[void][System.Reflection.Assembly]::LoadWithPartialName( "System.Windows.Forms")
[void][System.Reflection.Assembly]::LoadWithPartialName( "System.Drawing")
#Habilito los estilos visuales
[Windows.Forms.Application]::EnableVisualStyles()

function DomainCheck { 
$URL = "https://login.windows.net/" + $TextBoxDominio.Text + ".onmicrosoft.com/FederationMetadata/2007-06/FederationMetadata.xml"
$Solicitud = $null

try {
  Measure-Command {$Solicitud = Invoke-WebRequest -Uri $URL}
} catch {
  $Solicitud = $_.Exception.Response 
}

$Status = $Solicitud.StatusCode
  If ($Status -eq 200) {
    $LabelDomain.Text = "Dominio utilizado, por favor seleccionar otro."
  } else {
    $LabelDomain.Text = "Dominio disponible para usar en Office 365"
  }
}

########### Formulario Principal ###########

$Form = New-Object System.Windows.Forms.Form
$Form.Size = New-Object Drawing.Size(400,300)
$Form.StartPosition = "CenterScreen"
$Form.Text = "Office 365 Domain Check"

$LabelInfo = New-Object System.Windows.Forms.Label
$LabelInfo.Location = New-Object System.Drawing.Size(40,60)
$LabelInfo.Size = New-Object System.Drawing.Size(65,23)
$LabelInfo.Font = New-Object System.Drawing.Font("Sans Serif",10,[System.Drawing.FontStyle]::Bold)
$LabelInfo.Text = "Dominio:"
$Form.Controls.Add($LabelInfo)

$TextBoxDominio = New-Object System.Windows.Forms.TextBox
$TextBoxDominio.Location = New-Object System.Drawing.Size(110,58)
$TextBoxDominio.Size = New-Object System.Drawing.Size(120,23)
$Form.Controls.Add($TextBoxDominio)

$LabelOn = New-Object System.Windows.Forms.Label
$LabelOn.Location = New-Object System.Drawing.Size(235,58)
$LabelOn.Size = New-Object System.Drawing.Size(130,23)
$LabelOn.Font = New-Object System.Drawing.Font("Sans Serif",10,[System.Drawing.FontStyle]::Bold)
$LabelOn.Text = ".onmicrosoft.com"
$Form.Controls.Add($LabelOn)

$ButtonApply = New-Object System.Windows.Forms.Button
$ButtonApply.Location = New-Object System.Drawing.Size(90,100)
$ButtonApply.Size = New-Object System.Drawing.Size(200,30)
$ButtonApply.Text = "Chequear disponibilidad del dominio"
$ButtonApply.Add_Click({
  DomainCheck
})
$Form.Controls.Add($ButtonApply)

$ButtonExit = New-Object System.Windows.Forms.Button
$ButtonExit.Location = New-Object System.Drawing.Size(280,220)
$ButtonExit.Text = "Salir"
$ButtonExit.Add_Click({
  $Form.Close()
})
$Form.Controls.Add($ButtonExit)

$LabelDomain = New-Object System.Windows.Forms.Label
$LabelDomain.Location = New-Object System.Drawing.Size(60,170)
$LabelDomain.Size = New-Object System.Drawing.Size(300,23)
$LabelDomain.Text = ""
$LabelDomain.Font = New-Object System.Drawing.Font("Sans Serif",10,[System.Drawing.FontStyle]::Bold)
$Form.Controls.Add($LabelDomain)

$Form.ShowDialog() | Out-Null
{% endhighlight %}

El enlace para descargar el script es el siguiente:

[Chequear disponibilidad de dominio en Office 365](https://gallery.technet.microsoft.com/Chequear-disponibilidad-de-9a39fd0b)

Happy scripting!