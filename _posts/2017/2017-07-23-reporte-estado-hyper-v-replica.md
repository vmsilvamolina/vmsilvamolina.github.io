---
title: Reporte de estado de Hyper-V Replica
date: 2017-07-23T15:02:24+00:00
author: Victor Silva
layout: post
permalink: /reporte-estado-hyper-v-replica/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"3971085843e0";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:83:"https://medium.com/@vmsilvamolina/reporte-de-estado-de-hyper-v-replica-3971085843e0";}'
dsq_thread_id:
  - "6151714711"
categories:
  - Hyper-V
  - PowerShell
tags:
  - Get-VM
  - Get-VMReplication
  - Hyper-V Replica
  - PowerShell
  - Replica
---

En el blog anteriormente ya he hablado algo sobre Hyper-V Replica, aunque apuntando más a entender cómo funciona y que se debe tener en cuenta a la hora de implementar esta solución. El enlace a la publicación anterior sobre Hyper-V Replica es el siguiente:

  * [Hyper-V Replica para todos!!!](http://blog.victorsilva.com.uy/hyper-v-replica-para-todos/)

Para entender mejor que es lo que estamos haciendo vamos ir desarrollando el informe, de forma que podamos ir observando con detalle los puntos tratados.

## Manos a la obra

Vamos a comenzar el script ordenando la información requerida: en nuestro caso es necesario conocer cuáles son los servidores con el rol de Hyper-V que participan en la implementación de la solución. Considerando el diseño de la infraestructura de la herramienta tenemos 2 roles fundamentales: el **servidor primario**, que contiene las VMs en ejecución (o no) y el **servidor secundario**, que se encarga de alojar la transferencia de información y permanece en una postura pasiva hasta que se realice el _Failover_. Con lo anterior vamos a definir los parámetros de nuestra función:

{% highlight posh %}
[CmdletBinding()]
param (
    [Parameter(Position = 0, HelpMessage = 'Servidor de Hyper-V Replica primario')]
    [String]$PrimaryHyperV,

    [Parameter(HelpMessage = 'Servidor de Hyper-V Replica secundario')]
    [String]$SecondaryHyperV

)
{% endhighlight %}

Perfecto! Tenemos los servidores, ahora necesitamos saber cómo comprobar la salud de la implementación. Para ello vamos usar el cmdlet **_Get-VM_**, de la siguiente forma:

{% highlight posh %}
Get-VM -computername $PrimaryHyperV, $SecondaryHyperV | select Name,State,ReplicationHealth
{% endhighlight %}
    

En donde seleccionamos el nombre de la VM, el estado (si está apagada o corriendo) y la salud de la replicación. En consola obtenemos la siguiente salida:

<img src="https://ce2pww-ch3302.files.1drv.com/y4mldKaC1UsRpbZaElzvwU2O6v2kj_IyWtD-zMz_ImSTzXpnozF2xypGlD-yn5rQLo2i10n-ViHBYSgdJDRcwyoepEoxHxuXnRvMAk8rQ1e5Jsk5vVgnm_SdjuqjE6pAQJ450xZ2f_Prscvoy4mvxmtMPooJ6RfT9xvQ5yTsRyNp7PyYaH_WRcKu-1SvyAsAr6NR6-F-uetVHs8tnwX354L3g?width=878&#038;height=218&#038;cropmode=none" width="878" height="218" alt="Reporte de Hyper-V Replica" class="alignnone size-full" />

Con lo que desarrollamos anteriormente, es posible agregar un poco más de lógica y discriminar para que nos avise _solamente_ cuando las VMs no se encuentran en estado normal:

{% highlight posh %}
Get-VM -computername $PrimaryHyperV, $SecondaryHyperV `
| ? { $_.ReplicationHealth -eq "Warning" -or $_.ReplicationHealth -eq "Critical" } `
| select Name,State,ReplicationHealth
{% endhighlight %}

Otra opción es utilizar el cmdlet **_Get-VMReplication_** para obtener el status de la replicación, puediendo armar algo así:

{% highlight posh %}
$VmReplication = Get-VMReplication -ComputerName $PrimaryHyperV, $SecondaryHyperV  `
| Select-Object @{Name="Maquinas Virtuales";Expression={($_.Name)}},
                @{Name="Estado de la replica";Expression={($_.State)}},
                @{Name="Estado";Expression={($_.Health)}},
                @{Name="Host";Expression={($_.PrimaryServer)}} | ConvertTo-HTML -fragment
{% endhighlight %}

Como se muestra en el bloque anterior de código, se genera como salida un bloque HTML (tabla) que define los encabezados: Maquinas Virtuales, Estado de la replica, Estado, Host para desplegar más información al respecto.

## Recta final

Ya con este resultado podemos generar un mail que nos envíe esta tabla y así no estar revisando cada día la infraestructura de forma manual. Para ello agregamos la tabla resultante del cmdlet anterior como HTML al cuerpo del mail a enviar:

{% highlight posh %}
$Report = Get-VM -computername $PrimaryHyperV, $SecondaryHyperV | select Name,State,ReplicationHealth

$SMTPServer = "smtp.domain.com"
$SMTPCredentials = new-object Net.NetworkCredential("username", "PassW0rd")
$SMTP = new-object Net.Mail.SmtpClient($SMTPServer)
$SMTP.UseDefaultCredentials = $false
$SMTP.Credentials = $SMTPCredentials

$email.Subject = "Reporte de replicas"
$email.body = $Report
$smtp.Send($email)
{% endhighlight %}

> También podemos usar la función Send-MailMessage.

En estos momentos tenemos un informe funcional, que podemos programar para que se ejecute, por ejemplo, una vez al día.

Con todo lo que vimos anteriormente podemos armar un reporte, sumando cambios visuales con CSS, de la siguiente manera:

<script src="https://gist.github.com/vmsilvamolina/c683332a535f652570eb758d64f41364.js"></script>

Happy scripting!