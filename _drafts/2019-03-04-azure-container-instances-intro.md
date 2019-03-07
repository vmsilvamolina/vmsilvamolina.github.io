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
  az container create --resource-group aci-demo --name aci-demo --image microsoft/aci-helloworld --dns-name-label aci-demo --ports 80
{% endhighlight %}

¿Por qué utilizamos la imagen `microsoft/aci-helloworld`? Porque la imagen pertenece al repositorio público de Docker.

https://github.com/Azure-Samples/aci-helloworld

