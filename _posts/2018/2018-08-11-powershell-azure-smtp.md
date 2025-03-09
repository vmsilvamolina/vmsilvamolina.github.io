---
title: "Azure, SMTP y PowerShell"
date: 2018-08-11T18:57:00+00:00
author: Victor Silva
layout: post
permalink: /powershell-azure-smtp/
excerpt: "Me encontré con la necesidad de utilizar algún servicio de envío SMTP en Azure. La idea es poder enviar correos informando sobre ciertas acciones o situaciones de deploy, para una solución en particular. Dentro de todo lo que ofrece Azure, existe un servicio de terceros (no es el único) para realizar el envío SMTP de forma gratuita. Éste servicio ofrece enviar sin costo adicional hasta 25.000 correos por mes con la suscripción free."
categories:
  - PowerShell
  - Azure
tags:
  - PowerShell
  - Azure
  - SMTP
  - SMTP relay
  - SendGrid
  - Azure Functions
---

Me encontré con la necesidad de utilizar algún servicio de envío SMTP en Azure. La idea es poder enviar correos informando sobre ciertas acciones o situaciones de deploy, para una solución en particular. Dentro de todo lo que ofrece Azure, existe un servicio de terceros (no es el único) para realizar el envío SMTP de forma gratuita. Éste servicio ofrece enviar sin costo adicional **hasta 25.000 correos por mes** con la suscripción *free*.

El servicio es ofrecido por la empresa SendGrid y puede utilizarse también fuera de Azure.

Ahora bien, que necesitamos para poder utilizar el servicio? Primero, habilitarlo en Azure...

### Desplegar SendGrid en Azure

Para desplegar el servicio, debemos desde el portal buscar lo siguiente: SendGrid Email Delivery y seleccionar *create*.

<img src="https://w2dd5g.ch.files.1drv.com/y4m6zslyDFsfqubZjOi3nVRAbcjJp3cV7SEHvlybIqvdi4TVKMAMDXvEAHePcPPScZzBWsxIHnFxHnlGW4aMB5kh1mCh2tosKlpxZauENXiB5x_GapjZBXdL0LIY9ZqbFK2jT_k57UywkrKSFYe-stgcfoVYASWGmcnElOBx-iAd7OApP7XHvQmovc03r9GhN9VCzzXFQH-7NZGBtu0RHfxfQ?width=912&height=569&cropmode=none" width="912" height="569" alt="Crear el servicio de SendGrid en Azure" class="alignnone" />

Completamos el asistente con datos simples como contraseña, nombre y fundamental: el tipo de suscripción (free!). Ya con lo anterior, si revisamos el recurso que se muestra en el resource group tenemos lo siguiente:

<img src="https://8glnqg.ch.files.1drv.com/y4mjSWJ322Z0DxqiCa9tWEdQyV4afB1rgUV0GZnMaLXgQZu7GuOoi4ScpeQ5hElYRqax40j9JKKeEtWI1ZK7iMQNnwwyvFHZ432wgqCPe70lXLqVT0pauybYJH-VTnMuI-nxOiHbky8UY6dOKi7mzwTx8KQbXh1a86GUNcn6hTa6_I0IGMDg8O377l5fbal21liLDmHLk2e3kVWg5nbz9sCuQ?width=901&height=569&cropmode=none" width="901" height="569" alt="Dashboard SendGrid en Azure" class="alignnone" />

### Mandar el primer mail

Obviamente vamos a utilizar PowerShell para realizar el envío de mail, pero de que manera? A través de Azure Functions...

Como el sentido del post no es avanzar sobre Azure Functions, adjunto una entrada anterior que habla al respecto del tema:

[https://blog.victorsilva.com.uy/azure-functions/](https://blog.victorsilva.com.uy/azure-functions/)

No importa el tipo de template que utilicemos para generar la function app, el sentido del post es utilizar el servicio de SMTP principalmente. Para el ejemplo utilicé el template **Timer trigger**. 

Continuando con la estructura de lo que nos interesa, pasamos a ver el código.

Lo primero es destacar que cmdlet vamos a usar. Para enviar un mail tenemos [Send-MailMessage](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/send-mailmessage?view=powershell-6). Con el cmdlet anterior vamos a necesitar ciertos valores que serán nuestras variables:

- `$userName`
- `$password`
- `$smtpServer`
- `$emailFrom`
- `$emailTo`
- `$subject`
- `$body`

Al ser información sensible, lo recomendado es utilizar algún mecanismo para poder proteger estos datos. Para ello utilizamos la sección de **Application Settings** dentro de la *function app* creada.

De esta manera almacenamos información del tipo clave-valor utilizando el botón +*Add new setting* como indica la siguiente imagen:

<img src="https://w2da5g.ch.files.1drv.com/y4mm_fRZiEA0___4uBOWyV5uw3t4EVBIR1d8W-dS2QTVgXjSLPljw5TcZO4-DjIDprck0wA56RFVc_EDyRjsFThX1Qqz4mvdGcAQi3c8mr7tHLsM1KYF00FpXI_6LxFk3eA0yUYkSmqD7xbqSFiJ17vk--wfZ6cj7CREaNNmzIoko1RxES231qbdGwzu3hcXkI161A84gHAXhRpIs1Ff0l9qg?width=1122&height=485&cropmode=none" width="1122" height="485" alt="Add new setting en Aure Functions" class="alignnone" />

Ahora que tenemos esos valores dentro de un entorno más seguro, resta definir como trabajamos sobre ellas.

Al estar trabajando sobre PowerShell, todas las AppSettings se almacenan con la siguiente estructura:

> $ENV:APPSETTING_\<setting\>

En resumen, tendríamos que definir las variables con la información necesaria, generar las credenciales y utilizar el cmdlet **Send-MailMessage** para enviar un correo de prueba:

{% highlight posh%}
  #Obtengo los valores de AppSettings
  $User = $ENV:APPSETTING_SendGridUserName
  $PasswordText = $ENV:APPSETTING_SendGridPassword
  $smtpServer = $ENV:APPSETTING_SendGridServer
  #Genero las credenciales
  $Password = (ConvertTo-SecureString $PasswordText -AsPlainText -Force)
  $credential = New-Object System.Management.Automation.PSCredential $User, $Password
  #Defino información para enviar el mail
  $subject = "Test"
  $emailFrom = "vmsilvamolina@dominio.com"
  $emailTo = "vmsilvamolina@dominio.com"
  #Genero el cuerpo del mail
  $body = @"
  Mensaje de prueba
  "@
  #Envío el mail
  Send-MailMessage -smtpServer $smtpServer -Credential $credential -Usessl -Port 587 -from $emailFrom -to $emailTo -subject $subject -Body $body
{% endhighlight %}

Simple, no? Para el ejemplo ya tenemos configurado un sistema de envío de correos utilizando Azure Functions y SendGrid.

Happy scripting!