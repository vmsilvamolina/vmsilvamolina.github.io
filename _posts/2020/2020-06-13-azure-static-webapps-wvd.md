--- 
title: "Azure Static Web Apps al rescate de WVD"
author: Victor Silva
date: 2020-06-13T23:28:00+00:00 
layout: post 
permalink: /azure-static-webapps-wvd/
excerpt: "Windows Virtual Desktop presenta un cliente web para poder acceder a las aplicaciones/escritorios virtuales, pero este cliente tiene una URL genérica. Aquí es donde entra un nuevo servicio de Azure presentado en el Microsoft Build 2020: Static Web Apps, que nos va a permitir generar un website estático con una URL custom para direccionar a nuestros usuarios al portal de WVD."
categories: 
  - Azure
tags: 
  - Azure Static Web Apps
  - Windows Virtual Desktop

---

Windows Virtual Desktop presenta un cliente web para poder acceder a las aplicaciones/escritorios virtuales, pero este cliente tiene una URL genérica. Aquí es donde entra un nuevo servicio de Azure presentado en el Microsoft Build 2020: Static Web Apps, que nos va a permitir generar un website estático con una URL custom para direccionar a nuestros usuarios al portal de WVD.

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

Pero antes, es necesario cumplir con un requisito: tener un repositorio en GitHub. Así que desde la web de GitHub vamos a crear un nuevo repositorio, que por ahora va a estar vacío. Para el ejemplo vamos a utilizar:

**WVD-HomePage**

## Static Web App

Lo primero es crear el recurso en Azure, así que vamos a recurrir al portal de Azure para realizar la tarea. Desde el portal, seleccionar el botón crear recurso y buscar **Static Web App**.

Completar el asistente, tal como indica la siguiente imagen:

<img src="/assets/images/postsImages/PS_StaticWebApp_0.png" class="alignnone">

En la sección **Source Control Details** se debe iniciar sesión con nuestra cuenta de GitHub y autorizar para acceder a nuestro repo nuevo. Al finalizar se tendrá una configuración similar a la siguiente imange:

<img src="/assets/images/postsImages/PS_StaticWebApp_1.png" class="alignnone">

## Git Actions

Está el código, la web app y el repositorio, ahora resta unir todas las partes para disfrutar de nuestra solución! Y en estos momentos entra en juego **Git Actions**.

Lo primero que debemos hacer es volcar nuestro fantástico HTML al repositorio. Para ello:

{% highlight posh%}
cd \rutaDondeEstáElHTML
git add .
git commit -m "add index.html"
git push
{% endhighlight %}

Listo! Código en repo. Y Ahora, si nos fijamos en el repositorio, dentro de la sección **Actions**. Vamos a ver que existe un workflow ya creado: el CI/CD para publicar nuestros cambios.

Como ya tenemos un commit, se dispara la acción de publicar sobre la Static Web App tal como indica el workflow file (el pipeline para los amigos de Azure DevOps):

{% highlight yaml%}
  name: Azure Static Web Apps CI/CD

  on:
    push:
      branches:
        - master
    pull_request:
      types: [opened, synchronize, reopened, closed]
      branches:
        - master

  jobs:
    build_and_deploy_job:
      if: github.event_name == 'push' || (github.event_name == 'pull_request' && github.event.action != 'closed')
      runs-on: ubuntu-latest
      name: Build and Deploy Job
      steps:
        - uses: actions/checkout@v2
          with:
            submodules: true
        - name: Build And Deploy
          id: builddeploy
          uses: Azure/static-web-apps-deploy@v0.0.1-preview
          with:
            azure_static_web_apps_api_token: ${{ secrets.AZURE_STATIC_WEB_APPS_API_TOKEN_WONDERFUL_ISLAND_0C8BD4C0F }}
            repo_token: ${{ secrets.GITHUB_TOKEN }} # Used for Github integrations (i.e. PR comments)
            action: "upload"
            ###### Repository/Build Configurations - These values can be configured to match you app requirements. ######
            # For more information regarding Static Web App workflow configurations, please visit: https://aka.ms/swaworkflowconfig
            app_location: "/" # App source code path
            api_location: "api" # Api source code path - optional
            app_artifact_location: "" # Built app content directory - optional
            ###### End of Repository/Build Configurations ######

    close_pull_request_job:
      if: github.event_name == 'pull_request' && github.event.action == 'closed'
      runs-on: ubuntu-latest
      name: Close Pull Request Job
      steps:
        - name: Close Pull Request
          id: closepullrequest
          uses: Azure/static-web-apps-deploy@v0.0.1-preview
          with:
            azure_static_web_apps_api_token: ${{ secrets.AZURE_STATIC_WEB_APPS_API_TOKEN_WONDERFUL_ISLAND_0C8BD4C0F }}
            action: "close"
{% endhighlight %}

En el portal de Azure, dede el panel de overview del recurso Static Web App podemos sacar la URL a utilizar:

<img src="/assets/images/postsImages/PS_StaticWebApp_2.png" class="alignnone">

Si ahora navegamos a la URL de la Static Web App: `https://wonderful-island-0c8bd4c0f.azurestaticapps.net/` vamos a ser redirigidos a la URL de WVD.

## DNS: Custom domain

El útlimo paso es generar un CNAME de nuestro dominio para asociar la URL anterior a un nombre más lindo. Las instrucciones se encuentran en la sección custom domain dentro del recurso Static Web App:

<img src="/assets/images/postsImages/PS_StaticWebApp_3.png" class="alignnone">

Luego de generado el CNAME y validado por el asistente se creará el custom domain:

<img src="/assets/images/postsImages/PS_StaticWebApp_4.png" class="alignnone">

Ahora si podremos acceder a WVD usando la URL **wvd.victorsilva.com.uy**.

Con todo lo anterior, tenemos una solución para poder acceder a los servicios de Windows Virtual Desktop usando un nombre propio para el cliente web, por medio de una Static Web App en Azure.

Happy scripting!