---
title: Azure Functions
date: 2016-09-03T00:51:48+00:00
author: Victor Silva
layout: post
permalink: /azure-functions/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"8cc9ce505509";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:82:"https://medium.com/@vmsilvamolina/azure-functions-y-como-beneficiarse-8cc9ce505509";}'
dsq_thread_id:
  - "5334749367"
categories:
  - Azure
  - PowerShell
tags:
  - Azure
  - Azure Functions
  - PowerShell
  - Serverless
---
## Serverless Computing - Azure Functions

Aunque suene un poco contradictorio, el concepto de Serverless no significa que no hay un servidor, en realidad hace referencia a que no hay ningún servidor del que debemos preocuparnos. Ésta idea se asemeja bastante a lo que es **_Paas_**, aunque en realidad es un nuevo concepto que lo lleva a otro nivel.

Básicamente es una abstracción en la que solo debemos preocuparnos de que el código funcione correctamente y no sobre que plataforma (o servidor) se ejecuta. En pocas palabras, **_Azure Functions_** nos permite utilizar Azure para ejecutar código permitiendo elegir entre varios lenguajes:

  * Bash
  * Batch
  * C#
  * F#
  * JavaScript
  * PHP
  * PowerShell
  * Python

Ahora bien, no debemos perder de vista que Azure Functions permite ejecutar pequeñas piezas de código (funciones) en la nube. Vamos a considerar su uso para realizar tareas de procesamientos, solicitudes o mantenimiento de archivos logrando como consecuencia integrar sistemas, trabajar con Internet of Things (IoT) o construir APIs o microservicios.

## Crear nuestra primera Azure Function

Antes de comenzar a escribir nuestra primer función es necesario contar con una suscripción de Azure, en caso de no contar con una activa les comparto un [enlace](https://azure.microsoft.com/es-es/free/) para que puedan crear una.

Teniendo nuestra suscripción activa vamos a acceder al portal de [Azure Functions](https://functions.azure.com/signin) con las credenciales de Azure para poder comenzar a trabajar:

<img src="https://bv8lsa-ch3302.files.1drv.com/y4m_tPMQc_2yD2QxUmgEA-Oq1EbqiMLkRjRAZfdUzSsiKBEDKtdBeXgy1-yypE80K1Tsh-zg5Qx6Wuhliqhr7IKkWDy_y7Hq8BxEk4VhNvGwYZDOpGEBvBovEhgbyL4iqVC8fYt2sDFByslqTgokORUXE9nz9bsWACHmS7U-HVIucW0uxiA0eT050tKNNmNxLbMLwfQUOlVBtN2oDeE4WcCAQ?width=925&#038;height=652&#038;cropmode=none" width="905" height="638" alt="Azure Functions" class="alignnone size-medium" />

Para este ejemplo nombré la función como **PacktpubNotifier** como consecuencia a un requerimiento que pretendo resolver con Azure Functions y es el siguiente:

La editorial Packtpub todos los días ofrece un libro gratuito, para saber cuál es el libro (en caso de no estar registrados al newsletter) debemos acceder a [éste enlace](https://www.packtpub.com/packt/offers/free-learning) y en el sitio veremos los libros gratuitos de días anteriores así como el libro gratuito del día. Para no revisar el sitio cada día vamos a construir una función que nos notifique cada día que libro gratuito ofrece la editorial [Packtpub](http://packtpub.com). La notificación la vamos a realizar por medio de un mail, ya que todos los días la mayoría de nosotros revisa el correo.

Dentro de las regiones vamos a seleccionar la que más nos convenga según nuestros requerimientos. Elegí Brasil sólo para salir de las regiones de US (no me interesa la latencia).

### Scheduler

Vamos a seleccionar **Create + get started** para situarnos en la siguiente pantalla:

<img src="https://bv8msa-ch3302.files.1drv.com/y4mzx3lyHSnurap8fH6CcJxQYcAMvMbJTDWBMZ6c-Tg5Upe2NSKE9jhc-FX_nfcMR1EyuQyu0g5Ktj110lu0OgKqHsqFyzS3MDU2cU7Vx4ezvAFlQJ0NAQHKGyPS0oUXT_xbgktUjlSXSIBJITZ6410u6-j8qKpGOOKGKG_1v3LsXYOhIw9NmBE9sff3iEAxOkI_Z9UCgJErdrkr9d8t642xA?width=567&#038;height=529&#038;cropmode=none" width="567" height="529" alt="Azure Functions" class="alignnone size-medium" />

En donde nos aparecen algunas opciones preestablecidas para crear nuestra función. Como nosotros vamos a trabajar con PowerShell seleccionamos **_Our create your own custom function_**.

Vamos a seleccionar **_PowerShell_** como lenguaje y el template del tipo **_TimeTrigger_**. Antes de finalizar el asistente definiremos el nombre de la función:

<img src="https://bv8nsa-ch3302.files.1drv.com/y4m-3jzL9oQPtnBQlmlhm1hqDSMCD5c-KLPg1wDGwuIerbp4xccrXPIjFNbV4ysduxazLwqNM_vR0wdaT3Eudy-0d6USCSx6J7vFqYA8LR8lcYA6eNqpM5zmakC4LW1rlL5J9QBNk18BuGro7URe0twgpHqVMA77rsAu5FCIHXPrDlAgEV_LFnZI0A3gnERu9IcgdY0EQqZDqFx8TQntKEgDA?width=1166&#038;height=573&#038;cropmode=none" width="1166" height="573" alt="Azure Functions" class="alignnone size-medium" />

Por último debemos seleccionar la periodicidad en la que se va a ejecutar nuestra función. Azure Functions utiliza [expresiones CRON](https://en.wikipedia.org/wiki/Cron#CRON_expression) para planificar la ejecución de nuestra función. No pretendo profundizar sobre como funciona pero básicamente debemos tener clara la estructura que es la siguiente:

    {second} {minute} {hour} {day} {month} {day of the week}
    

Para el ejemplo, vamos a requerir que la ejecución se realice una vez por día, a las 10:00hs (UTC-03:00):

    0 0 13 * * *
    

Ingresamos la estructura anterior y seleccionamos create:

<img src="https://bv8osa-ch3302.files.1drv.com/y4mJSkvdE10qOgOG5bOYHAF2pKKgTHfCwk3nICUA01HZDlOZg3UlTRwSES_OETZhGHNbF9OOvWz7Erd43zQvonqnLOeEzqAvQ9wkHV3RNFB96LCu9Bp9h9ThDsqdE8g_DzRtH3rnh08sqQANqEV6B3KJEQaHUzEVnMNTPiQnECZ8glazeC0U5uz6_6reoVI_wbisd1MwpccYsqGeYTwu4dhjQ?width=377&#038;height=394&#038;cropmode=none" width="377" height="394" alt="Schedule" class="alignnone size-medium" />

### Código

Ahora nos toca desarrollar la parte de código, vamos a utilizar el cmdlet Invoke-WebRequest con el que obtendremos el dato que necesitamos para enviar al mail. Destacar que el comando solamente puede ejecutarse con el parámetro **_-UseBasicParsing_** por lo que es necesario manipular los datos de forma más extensa, de la siguiente manera:

{% highlight posh %}
#Datos
$web = Invoke-WebRequest -Uri https://www.packtpub.com/packt/offers/free-learning -UseBasicParsing
$texto = ($web.RawContent -split '<div class="dotd-title">' | select -Last 1)
$title = (($texto -split '</h2>' | select -First 1) -split '<h2>' | select -Last 1).trim()
#Credenciales
$user = 'vmsilvamolina@victorsilva.com.uy'
$pass = (ConvertTo-SecureString 'XXXXXXXXXXXXXX' -AsPlainText -Force)
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $pass
#Envío de mail 
$date = Get-Date -Format dd/MM
Send-MailMessage -To vmsilvamolina@gmail.com -From vmsilvamolina@victorsilva.com.uy -Subject "Packtpub: Libro gratis - $date" -Body $title -SmtpServer smtp.office365.com -UseSsl -Credential $cred -Port 587
{% endhighlight %}

<img src="https://bv8psa-ch3302.files.1drv.com/y4mdUB9LN6zsZclCrj6eUrtfw86p_Ry6Icav-wy992B1ztEV5k5wvlx3xg_71YTKPmDhSA0LlZC8P9aYJLc3DRW_vayq1b2yELmFFbUb4HfyaOwJfWuW_elUUe45KtanfbmKfcOsLz_1u6l6JvC6dw5GVoZ8c-svHrp4YMcaTSgTGh0WGdN422lsZCoHKUiCx0qcy5OUhnCcw1aYjV1Rnooug?width=1305&#038;height=501&#038;cropmode=none" width="1305" height="501" alt="Azure Functions - Código" class="alignnone size-medium" />

Ya con el código ingresado, vamos a guardar los cambios y posteriormente a que se ejecute, para poder obtener como resultado nuestro mail con la información del libro sin necesidad de acceder a la página, utilizando una función simple en Azure.

Happy scripting!