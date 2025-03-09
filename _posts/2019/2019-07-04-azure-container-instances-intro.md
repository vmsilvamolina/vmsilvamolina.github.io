--- 
title: "Container Instances desde la línea de comandos"
author: Victor Silva
date: 2019-07-04T07:17:00+00:00 
layout: post 
permalink: /azure-container-instances-intro/ 
excerpt: "Azure Container Instances es una solución que nos permite ejecutar contenedores basados en imágenes, públicas o privadas, partiendo del la siguiente premisa: no es necesario provisionar ningún tipo de infraestructura antes de ejecutar el o los contenedores. Sumado a la falta de necesidad de administrar la plataforma, este servicio tiene un modelo de facturación por segundo, lo que significa que vamos a pagar únicamente el tiempo en que el contenedor se encuentre en ejecución." 
categories: 
  - Azure
  - DevOps 
  - PowerShell 
tags: 
  - Azure
  - Azure Container Instances
  - PowerShell
  - Azure CLI
---
Azure Container Instances es una solución que nos permite ejecutar contenedores basados en imágenes, públicas o privadas, partiendo del la siguiente premisa: no es necesario provisionar ningún tipo de infraestructura antes de ejecutar el o los contenedores. Sumado a la falta de necesidad de administrar la plataforma, este servicio tiene un modelo de facturación por segundo, lo que significa que vamos a pagar únicamente el tiempo en que el contenedor se encuentre en ejecución. Si necesitamos ejecutar un container por 20 minutos y luego lo eliminamos, vamos a tener que pagar solamente por esos 20 minutos que el contenedor se ha estado ejecutando.

Por ende nuestra preocupación se va a centrar en desplegar el contenedor y en detenerlo cuando no lo necesitemos más, pero no en eliminar la infrastructura que se ha generado por detrás. Aunque suena demasiado "cool", este servicio no es para todos los escenarios como por ejemplo un web server, ya que el costo a largo plazo es más caro que en otras soluciones disponibles. Pero sí sería muy útil en escenarios de testing o experimentales, en procesos batch o todos aquellos que sean efímeros.


## Creando el primer recurso ACI

Para trabajar sobre Azure Container Instances desde la consola tenemos la opción de **Azure CLI** o utilizar el módulo de PowerShell **Az**. Debido a que el contenido del post es lograr desplegar los recursos de una forma sencilla, voy a detallar en el siguiente procedimiento los pasos ejecutar con *Azure CLI* desde la Cloud Shell usando *Bash* desde mi *Windows Terminal*.

Lo primero es identificar un Resource Group dentro de nuestra subscription en Azure para alojar los recursos, o de lo contrario crear uno:

{% highlight posh%}
  az group create \
    --location EastUs \
    --name aci-demo
{% endhighlight %}

Ya con el contenedor disponible, lo siguiente es generar el recurso Azure Container Instance utilizando una imagen ya armada por parte de Microsoft, el viejo y querido "Hello World":

{% highlight posh%}
  az container create \
    --resource-group aci-demo \
    --name aci-container \
    --image microsoft/aci-helloworld \
    --dns-name-label aci-demo-blog \
    --ports 80
{% endhighlight %}

¿Por qué utilizamos la imagen `microsoft/aci-helloworld`? Porque la imagen pertenece al repositorio público de Docker. Más información sobre la imagen:

[https://github.com/Azure-Samples/aci-helloworld](https://github.com/Azure-Samples/aci-helloworld)

Luego de esperar unos segundos a que finalice el deploy, es necesario ejecutar el siguiente comando para extraer la información sobre el recurso desplegado:

{% highlight posh%}
  az container show \
    --resource-group aci-demo \
    --name aci-container \
    --query "{FQDN:ipAddress.fqdn,ProvisioningState:provisioningState}" \
    --out table
{% endhighlight %}

<img src="/assets/images/postsImages/AZ_ACI_01.png" alt="Show container provisioningState" class="alignnone"/>

Si el valor de `ProvisioningState` es **Succeeded**, entonces al acceder desde el navegador utilizando el FQDN resultante, se debería desplegar algo como la siguiente imagen:

<img src="/assets/images/postsImages/AZ_ACI_02.png" alt="Hello world webpage" class="alignnone"/>

Si esto es así, felicitaciones! Se ha desplegado correctamente un container de Docker sobre Azure utilizando el servicio Container Instances.

## Próximos pasos

Tenemos una imagen ya armada en un contenedor corriendo con lo básico de configuración. ¿Cómo podemos cambiar esos valores? Lo primero que debemos hacer es enfocar la atención en el comando `az container create`, donde vamos a ver los siguientes ejemplos:

Si queremos correr el contenedor anterior con 2 cpus y 3.5GB de memoria, debemos ejecutarlo de la siguiente manera:

{% highlight posh%}
  az container create \
    --resource-group aci-demo \
    --name aci-container2 \
    --image nginx:latest \
    --dns-name-label aci-blog-nginx \
    --os-type Linux \
    --cpu 2 \
    --memory 3.5
{% endhighlight %}

(Para el ejemplo utilicé otra imagen de contenedor)

En caso de querer ver que realmente se encuentre con la configuración deseada, podemos volver a utilizar el comando `az container show` así:

{% highlight posh%}
  az container show \
    --resource-group aci-demo \
    --name aci-container2 \
    --output table
{% endhighlight %}

Obteniendo como resultado:

<img src="/assets/images/postsImages/AZ_ACI_03.png" alt="Container info" class="alignnone"/>

Lo siguiente es ver como armar una imagen y publicarla en un Container Registry en Azure para luego ejecutar un container en Container Instances, así que atentos al blog...

Happy Scripting!