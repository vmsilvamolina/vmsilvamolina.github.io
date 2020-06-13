--- 
title: "Azure Static Web Apps al rescate de WVD"
author: Victor Silva
date: 2020-06-13T23:28:00+00:00 
layout: single 
permalink: /azure-static-webapps-wvd/
excerpt: "Windows Virtual Desktop presenta un cliente web para poder acceder a las aplicacions/escritorios virtuales, pero este cliente tiene una URL genérica. Aquí es donde entra un nuevo servicio de Azure presentado en el Microsoft Build 2020: Static Web Apps, que nos va a permitir generar un website estático con una URL custom para direccionar a nuestros usuarios al portal de WVD."
categories: 
  - Azure
tags: 
  - Azure Static Web Apps
  - Windows Virtual Desktop

---

Windows Virtual Desktop presenta un cliente web para poder acceder a las aplicacions/escritorios virtuales, pero este cliente tiene una URL genérica. Aquí es donde entra un nuevo servicio de Azure presentado en el Microsoft Build 2020: Static Web Apps, que nos va a permitir generar un website estático con una URL custom para direccionar a nuestros usuarios al portal de WVD.

## Website

Lo primero es definir el sitio que vamos a publicar como Static Web App y, para hacer eso, lo primero que hay que generar es el repositorio en GitHub. Como el objetivo del post no es 

Ya con el repositorio creado, el siguiente paso es genenar el sitio a publicar. A modo de simplificarlo al extremo, se utilizará el objeto `window.location` para definir la URL destino, que en este caso, es la URL del cliente de WVD: https://rdweb.wvd.microsoft.com/webclient/index.html.

Así quedaría el código HTML:

{% highlight HTML%}
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>WVD - HomePage</title>
        <script type = "text/javascript">
            window.location = "https://rdweb.wvd.microsoft.com/webclient/index.html";
        </script>
    </head>
    <body>
    </body>
    </html>
{% endhighlight %}

Si guardamos el código anterior y lo ejecutamos en un navegador nos redireccionará al cliente web tal como necesitamos. Ahora tenemos que publicarlo en Azure y acá es donde entra en acción, Azure Static Web Apps...

## Static Web App

<img src="/assets/images/postsImages/PS_StaticWebApp_0.png" class="alignnone">

<img src="/assets/images/postsImages/PS_StaticWebApp_1.png" class="alignnone">





https://github.com/MariuszFerdyn/WindowsVirtualDesktopHomePage

https://codepen.io/kenchen/pen/tgBiE