---
id: 1516
title: PowerShell Polaris
date: 2017-10-23T23:35:53+00:00
author: Victor Silva
layout: post
guid: http://blog.victorsilva.com.uy/?p=1516
permalink: /powershell-polaris/
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

### Instalación

La instalación de PowerShell Polaris es bastante sencilla, simplemente hay cumplir con 2 requerimientos:

  * PowerShell Core 6
  * .NET Standard 2.0 SDK
  * Git (solo es necesario para clonar el repositorio, de lo contrario descargar el repositorio como .zip)

Y los pasos a seguir son:

    git clone https://github.com/PowerShell/Polaris.git
    cd Polaris/PolarisCore
    

<img src="https://pbpqow-ch3302.files.1drv.com/y4mHz7FcoDTLCznij008e8Olj_CWed4v3Td8wrwJId6oLb4ZPId_XWEQqQ5Vg87VoYisaJWJEIMxHEfkUnyZxkmUEqfrpz11jeEPI-Ff3gwMsOIxIw7mDIzvOtcOIdaA9Zgsk9HP0-RjwPlcRFLtTh9bgy4llZMRqDCx4Jwoce-Fh_KliS10gJySaE5p4d4WzzJ4fP3Y2_Fl2frGT0DcaanyQ?width=979&#038;height=485&#038;cropmode=none" width="979" height="485" alt="Parte del proceso de instalación de PowerShell Polaris" class="alignnone size-full" />

Posteriormente ejecutar para finalizar la instalación:

    dotnet restore
    dotnet build
    cd ..
    Import-Module ./Polaris.psm1
    

Finalmente luego del arduo trabajo tenemos Polaris instalado en el equipo!

### Primeros pasos

Al momento de comenzar a utilizar este framework no comprendía realmente el alcance del proyecto, por ello es que quiero mostrarles un ejemplo de uso para que puedan entenderlo mejor y sacarle provecho.

Lo primero que vamos a hacer es ver los cmdlets que vienen en el módulo ejecutando:

    Get-Command -Module Polaris
    

<img src="https://pbppow-ch3302.files.1drv.com/y4mFB_R2YIvtw0JnsksjNwsXboL5_YVth3WQSRW79y1umkEzD7Lf2fI3OYT7mmDa-Y65uxl297oLb4_OubK04YmQt77aGo12foPzNkBN8lif1433xAohd7ImZfbRbL8m4RC0rztev5PwS4Qyl2AHpD4er9IIr_P-NGW9aKJa8ToK5gX13i-YhdwnV7aHYEPDD2E3__-lkAdeIOORFawfs3edQ?width=979&#038;height=433&#038;cropmode=none" width="979" height="433" alt="Cmdlets de PowerShell Polaris" class="alignnone size-full" />

El primer cmdlet que vamos a utilizar para el ejemplo es **_New-WebRoute_** y nos permite definir una ruta HTTP en la que nuestro webserver va a escuchar. Simplemente para refrescar la memoria, gracias al protocolo HTTP podemos comunicarnos utilizando el esquema _request-response_ en donde existen varios métodos de petición (GET, POST, PUT, etc.) para realizar acciones sobre el servidor.

Como parte del ejemplo, nos resta comentar que commando tenemos para iniciar el servidor. Para ello vamos a utilizar **_Start-Polaris_**. A modo de comentario vale la pena aclarar que el puerto por defecto del servidor es el **8080**. En caso de querer definir un puerto diferente, debemos utilizar el parámetro _Port_.

Así que vamos a crear el &#8220;Hola Mundo!&#8221; en nuestro flameante servidor de la siguiente manera:

    #Primero definimos la ruta con el método
    New-GetRoute -Path "/helloworld" -ScriptBlock {
        $response.Send('Hello World!');
    }
    #Iniciamos el server en el puerto 8081
    $app = Start-Polaris -Port 8081
    

Para comprobar lo que realizamos, accedemos desde un navegador a la siguiente dirección: <http://localhost:8081/helloworld> y vamos a poder ver lo siguiente:

<img src="https://pbp8ow-ch3302.files.1drv.com/y4mADcZD3TVdZZEzHf9ahzqe6gK5muiV_ujPaVKFKD0H5Jfm43Qc-zyxL9CkDlhNJvN7Fhv8WXZlS7sv-BBUOZF1yhTWES1xM8lfiNlpJIvgo8bybtenbB86qeV0H02hsH2ru4oJokd7peXE1pwumeOVdbkWdwQVJIF-_dHbv8wcvjzoL2ytL4sJHcyUWgfTRZu9nfGaUX-vnEKiUJoqUAlbw?width=783&#038;height=408&#038;cropmode=none" width="783" height="408" alt="Hello World en nuestro servidor!" class="alignnone size-full" />

En caso de querer finalizar el servidor, debemos ejecutar:

    Stop-Polaris -ServerContext $app
    

Saludos,