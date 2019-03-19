--- 
title: "Azure Container Instances desde la línea de comandos"
author: Victor Silva
date: 2019-03-04T07:17:00+00:00 
layout: single 
permalink: /azure-container-instances-intro/ 
excerpt: "" 
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

Azure Container Instances

## Creando el primer recurso ACI

Para trabajar sobre Azure desde la consola tenemos 2 opciones: Usar **Azure CLI** o utilizar PowerShell, con el módulo **Az**, debido a que el contenido del post es lograr 

{% highlight posh%}
  az container create --resource-group aci-demo --name aci-container --image microsoft/aci-helloworld --dns-name-label aci-demo --ports 80
{% endhighlight %}

¿Por qué utilizamos la imagen `microsoft/aci-helloworld`? Porque la imagen pertenece al repositorio público de Docker. Más información sobre la imagen:

[https://github.com/Azure-Samples/aci-helloworld](https://github.com/Azure-Samples/aci-helloworld)

Luego de esperar unos segundos a que finalice el deploy, es necesario ejecutar el siguiente comando para extraer la información sobre el recurso desplegado:

{% highlight posh%}
  az container show --resource-group aci-demo --name aci-container --query "{FQDN:ipAddress.fqdn,ProvisioningState:provisioningState}" --out table
{% endhighlight %}

<img src="/assets/images/postsImages/AZ_ACI_01.jpg" alt="Show container provisioningState" class="alignnone" />

Si el valor de `ProvisioningState` es **Succeeded**, entonces debemos acceder desde el navegador utilizando el FQDN resultante, donde se debería desplegar algo como la siguiente imagen:

<img with the browser fqdn>

Si esto es así, felicitaciones! Se ha desplegado correctamente una aplicación corriendo en un container de Docker sobre Azure.

https://azure.microsoft.com/es-es/services/container-instances/
https://docs.microsoft.com/en-us/azure/container-instances/container-instances-overview


https://blogs.encamina.com/por-una-nube-sostenible/containerless-una-version-serverless-de-contenedores-en-azure/