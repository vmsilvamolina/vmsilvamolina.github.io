---
title: PowerShell Polaris
date: 2017-10-23T23:35:53+00:00
author: Victor Silva
layout: post
permalink: /powershell-polaris/
excerpt: "PowerShell Polaris es un framework web, multi plataforma, que se ejecuta sobre PowerShell Core 6. Antes de seguir con los detalles de Polaris, quiero recalcar que un 'web framework' es: Es un entorno de trabajo diseñado para apoyar el desarrollo de aplicaciones web, incluyendo servicios y APIs."
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"84a8685406ae";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:65:"https://medium.com/@vmsilvamolina/powershell-polaris-84a8685406ae";}'
dsq_thread_id:
  - "6236659582"
categories:
  - PowerShell
tags:
  - Framework
  - GitHub
  - Polaris
  - PowerShell
  - PowerShell Polaris
---

PowerShell Polaris es un framework web, multi plataforma, que se ejecuta sobre PowerShell Core 6. Antes de seguir con los detalles de Polaris, quiero recalcar que un **_web framework_** es:

> Es un entorno de trabajo diseñado para apoyar el desarrollo de aplicaciones web, incluyendo servicios y APIs.

O sea que vamos a tener a partir de nuestro querido PowerShell un web server reducido, pero que nos va a permitir hacer cosas muy divertidas.

## Instalación

La instalación de PowerShell Polaris es bastante sencilla, simplemente hay cumplir con 2 requerimientos:

  * PowerShell Core 6
  * .NET Standard 2.0 SDK
  * Git (solo es necesario para clonar el repositorio, de lo contrario descargar el repositorio como .zip)

Y los pasos a seguir son:

{% highlight posh %}
git clone https://github.com/PowerShell/Polaris.git
  cd Polaris/PolarisCore
{% endhighlight %}
    

<img src="https://pbpqow-ch3302.files.1drv.com/y4mHz7FcoDTLCznij008e8Olj_CWed4v3Td8wrwJId6oLb4ZPId_XWEQqQ5Vg87VoYisaJWJEIMxHEfkUnyZxkmUEqfrpz11jeEPI-Ff3gwMsOIxIw7mDIzvOtcOIdaA9Zgsk9HP0-RjwPlcRFLtTh9bgy4llZMRqDCx4Jwoce-Fh_KliS10gJySaE5p4d4WzzJ4fP3Y2_Fl2frGT0DcaanyQ?width=979&#038;height=485&#038;cropmode=none" width="979" height="485" alt="Parte del proceso de instalación de PowerShell Polaris" class="alignnone size-full" />

Posteriormente ejecutar para finalizar la instalación:

{% highlight posh %}
dotnet restore
  dotnet build
  cd ..
  Import-Module ./Polaris.psm1
{% endhighlight %}

Finalmente luego del arduo trabajo tenemos Polaris instalado en el equipo!

## Primeros pasos

Al momento de comenzar a utilizar este framework no comprendía realmente el alcance del proyecto, por ello es que quiero mostrarles un ejemplo de uso para que puedan entenderlo mejor y sacarle provecho.

Lo primero que vamos a hacer es ver los cmdlets que vienen en el módulo ejecutando:

{% highlight posh %}
Get-Command -Module Polaris
{% endhighlight %}

<img src="https://pbppow-ch3302.files.1drv.com/y4mFB_R2YIvtw0JnsksjNwsXboL5_YVth3WQSRW79y1umkEzD7Lf2fI3OYT7mmDa-Y65uxl297oLb4_OubK04YmQt77aGo12foPzNkBN8lif1433xAohd7ImZfbRbL8m4RC0rztev5PwS4Qyl2AHpD4er9IIr_P-NGW9aKJa8ToK5gX13i-YhdwnV7aHYEPDD2E3__-lkAdeIOORFawfs3edQ?width=979&#038;height=433&#038;cropmode=none" width="979" height="433" alt="Cmdlets de PowerShell Polaris" class="alignnone size-full" />

El primer cmdlet que vamos a utilizar para el ejemplo es **_New-WebRoute_** y nos permite definir una ruta HTTP en la que nuestro webserver va a escuchar. Simplemente para refrescar la memoria, gracias al protocolo HTTP podemos comunicarnos utilizando el esquema _request-response_ en donde existen varios métodos de petición (GET, POST, PUT, etc.) para realizar acciones sobre el servidor.

Como parte del ejemplo, nos resta comentar que comando tenemos para iniciar el servidor. Para ello vamos a utilizar **_Start-Polaris_**. A modo de comentario vale la pena aclarar que el puerto por defecto del servidor es el **8080**. En caso de querer definir un puerto diferente, debemos utilizar el parámetro _Port_.

Así que vamos a crear el "Hola Mundo!" en nuestro flamante servidor de la siguiente manera:

{% highlight posh %}
#Primero definimos la ruta con el método
  New-GetRoute -Path "/helloworld" -ScriptBlock {
    $response.Send('Hello World!');
  }
  #Iniciamos el server en el puerto 8081
  $app = Start-Polaris -Port 8081
{% endhighlight %}

Para comprobar lo que realizamos, accedemos desde un navegador a la siguiente dirección: <http://localhost:8081/helloworld> y vamos a poder ver lo siguiente:

<img src="https://pbp8ow-ch3302.files.1drv.com/y4mADcZD3TVdZZEzHf9ahzqe6gK5muiV_ujPaVKFKD0H5Jfm43Qc-zyxL9CkDlhNJvN7Fhv8WXZlS7sv-BBUOZF1yhTWES1xM8lfiNlpJIvgo8bybtenbB86qeV0H02hsH2ru4oJokd7peXE1pwumeOVdbkWdwQVJIF-_dHbv8wcvjzoL2ytL4sJHcyUWgfTRZu9nfGaUX-vnEKiUJoqUAlbw?width=783&#038;height=408&#038;cropmode=none" width="783" height="408" alt="Hello World en nuestro servidor!" class="alignnone size-full" />

En caso de querer finalizar el servidor, debemos ejecutar:

{% highlight posh %}
Stop-Polaris -ServerContext $app
{% endhighlight %}

## Un ejemplo más funcional…

Ahora vamos a ver un ejemplo un poco más divertido, que nos demuestra el potencial de este proyecto. Al ser un webserver montado sobre PowerShell, tenemos a disposición para utilizar comandos que impacten sobre el resultado de la consulta (por ejemplo un GET), por lo que cada vez que realicemos la consulta obtendremos un valor actualizado.

La demostración más sencilla que se me ocurrió es consultar la hora, ya que es un valor que va cambiando constantemente. Así que vamos a construir lo siguiente:

{% highlight posh %}
New-GetRoute -Path "/time" -ScriptBlock {
    $time = Get-Date -DisplayHint Time
    $response.Send("Que hora es?: $time");
  }
{% endhighlight %}
 
Posteriormente iniciamos la instancia:

{% highlight posh %}
$app = Start-Polaris -Port 8088
{% endhighlight %}

Y luego consultamos el resultado, ya sea desde la web (accediendo a la URL con el puerto y la ruta) o utilizando el cmdlet Invoke-RestMethod, de la siguiente manera:

{% highlight posh %}
Invoke-RestMethod -Uri http://localhost:8088/time -Method GET
{% endhighlight %}

<img src="https://fo1cxg-ch3302.files.1drv.com/y4mIEWgXZAETvWwRd-JDjWqjci-HjgZKQMQnjH6D6dtdUBwyyFzas9IpLcsTxOvwajQbagFj238Q5m_i10-yiGkGkajqCzQtjB3ZqkygwKOJZNrp96N124K998NVXZdyyntAy0dp5FH086Qvp7j6udV5zbtokIUNF7I0ZhLqHM8zim26XR8-LUD8hy6-rAvdzkP7f3W4WeeYePz7ujabi61PA?width=861&height=223&cropmode=none" width="861" height="223" alt="Invoke-RestMethod" class="alignnone size-full" />

En donde vamos a obtener resultados actualizados, en función de lo definido en la ruta.

Happy scripting!