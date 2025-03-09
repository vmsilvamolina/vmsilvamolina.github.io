---
title: Reporte de Snapshots de VMs en VMware
date: 2017-01-14T23:34:11+00:00
author: Victor Silva
layout: post
permalink: /snapshots-de-vms-en-vmware/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"a3d3545ace6b";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:84:"https://medium.com/@vmsilvamolina/reporte-de-snapshots-de-vms-en-vmware-a3d3545ace6b";}'
dsq_thread_id:
  - "5971604922"
categories:
  - PowerShell
tags:
  - PowerCLI
  - PowerShell
  - Reporte
  - Snapshots
  - VMware
---
En oportunidades anteriores se ha hablado sobre la proyección de PowerShell fuera del mundo Microsoft, en donde empresas externas han desarrollado extensiones para utilizarse desde PowerShell. Una de ellas es VMware, en donde ha crecido de manera exponencial el uso de PowerShell para realizar la administración de la plataforma. Es en este post que se pretende mostrar como podemos resolver una situación en la que necesitamos un reporte de snapshots de VMs en VMware con PowerShell.

## La consola de PowerShell para VMware

Dentro del mundo VMware se conoce popularmente la consola de administración por scripting como **_PowerCLI_**. Desde nuestra querida consola de PowerShell es posible trabajar con la plataforma de VMware realizando una simple acción: cargando el _pssnappin_ que VMware nos deja a disposición.

Hay que aclarar que para contar con este _pssnappin_, es necesario descargar el PowerCLI desde la página de VMware y realizar la instalación correspondiente, utilizando [éste enlace](https://my.vmware.com/web/vmware/details?productId=614&downloadGroup=PCLI650R1).

Ya con la instalación realizada basta con ejecutar en la consola de PowerShell:

{% highlight posh %}
Add-PSSnapin VMware.VimAutomation.Core
{% endhighlight %}

Podemos escribir un poco más de código y comprobar si se encuentra cargado desde el inicio y, a su vez, comprobar que se encuentre instalado:

{% highlight posh %}
If (-not (Get-PSSnapin VMware.VimAutomation.Core)) {
    Try { Add-PSSnapin VMware.VimAutomation.Core -ErrorAction Stop }
    Catch { Write-Host "PowerCLI no se puede agregar, está instalado?" -ForegroundColor Red; Break }
}
{% endhighlight %}    

Ahora que sabemos si cumplimos el requisito para utilizar los comandos que dispone VMware, debemos definir el servidor al que pretendemos conectarnos y con qué credenciales vamos a realizar la conexión, utilizando el siguiente comando:

{% highlight posh %}
$VIServer = "<serverName>"
Connect-VIServer $VIServer 
{% endhighlight %}

A continuación, vamos a utilizar el siguiente fragmento de código. En el mismo, lo primero que accionamos es la obtención de las máquinas virtuales del servidor y de cada una de ellas si tiene spanshot o no. De lo anterior filtramos seleccionando los datos que realmente nos interesan para el reporte (también se manipula el tamaño, para que sea representado con un formato amigable). Luego vamos a exportarlo como .html:

{% highlight posh %}
$PathToReport = "C:\"
$Report = Get-VM | Get-Snapshot | Select VM,Name,Description,@{Label="Size";Expression={"{0:N2} GB" -f ($_.SizeGB)}},Created
If (-not $Report)
{  $Report = New-Object PSObject -Property @{
        VM = "No se encontraron snapshots en ninguna de las VMs del $VIServer"
        Name = ""
        Description = ""
        Size = ""
        Created = ""
    }
}

$Header = @"
<style>
TABLE {border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
TH {border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color: #3A539B;color: white;}
TD {border-width: 1px;padding: 3px;border-style: solid;border-color: black;}
</style>
"@

$MyObject | Select 'Folder Name',Owner,'Created On','Last Updated',Size | ConvertTo-HTML -Head $Header

$Report = $Report | Select VM,Name,Description,Size,Created | ConvertTo-Html -Head $Header -PreContent "<p><h2 style='font-family: Segoe UI Light,Arial;'>Reporte de Snapshots - $VIServer</h2></p><br>"
$Report | Out-File $PathToReport\SnapShotReport.html
{% endhighlight %}

Logrando un resultado como el siguiente:

<img src="https://du01fw-ch3302.files.1drv.com/y4m4WoTfNl7kNIIqHg5ysFEW74c1yM-EqgVWnIX_0r9_IT4JKwiA-pfF0-IvGYQv4qUUZadh_iTvBOePJ8HiuXwoCHzjWbcLg0ga1qcE0L7F96-kaNAVrAJA_5CN3KN9MNPIhvITm6q87z3RHIFUZJdt-CAJUOglKQRbJw0MfE_1-3EwctXipXUfKbZsN8YN-QF4TkCc6Pb3kvty3khVWCzJg?width=793&#038;height=264&#038;cropmode=none" width="793" height="264" alt="Reporte de Snapshots de VMs en VMware" class="alignnone size-medium" />

Ahora que tenemos el archivo .html, resta agregar la función Send-MailMessage. Con ella se enviará el reporte de snapshots de VMs en VMware a las personas interesadas. Un ejemplo de uso de la función sería:

{% highlight posh %}
Send-MailMessage -From "User01 <user01@example.com>" -to "User02 <user02@example.com>" -Subject "Reporte de Snapshots" -Body "Se adjunta el reporte de snapshots de VMware." -Attachments "SnapShotReport.html" -SmtpServer smtp.server.com
{% endhighlight %}

Y de esta manera, tenemos al final un reporte funcional con la información requerida de los Snapshots de nuestra plataforma de VMware utilizando la consola de PowerShell de forma simple.

Happy scripting!