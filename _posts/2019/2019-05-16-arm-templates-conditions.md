--- 
title: "Condiciones en ARM templates"
author: Victor Silva
date: 2019-05-16T11:51:00+00:00 
layout: post 
permalink: /arm-templates-conditions/ 
excerpt: 'Azure Resource Manager es "la" solución que ofrece Microsoft para hacer el deploy en Azure de forma nativa. Y cuando digo LA es porque, si bien existen otras soluciones, Azure Resource Manager es la base fundamental de los recursos actuales. También es cierto que algunos templates de ARM pueden volverse muy largos y confusos cuando agrupan la definición de varios recursos, ya que la estructura de JSON no es la mejor aliada para estos casos.' 
categories: 
  - Azure
  - DevOps
tags: 
  - Azure
  - Azure DevOps
  - Azure CLI
  - PowerShell
---

Azure Resource Manager es "la" solución que ofrece Microsoft para hacer el deploy en Azure de forma nativa. Y cuando digo LA es porque, si bien existen otras soluciones, Azure Resource Manager es la base fundamental de los recursos actuales. También es cierto que algunos templates de ARM pueden volverse muy largos y confusos cuando agrupan la definición de varios recursos, ya que la estructura de JSON no es la mejor aliada para estos casos.

<img src="/assets/images/postsImages/AZ_ARM_templates_1.png" class="alignnone" />

De todas formas, ARM juega un papel fundamental en los despliegues y hoy vamos a ver un particularidad de éstos, como lo son las condiciones.

> Azure Resource Manager is the deployment and management service for Azure


## Condiciones en ARM

Desde hace un tiempo tenemos disponible en los templates ARM la key llamada **condition**, que se puede aplicar a un recurso para determinar si se ejecuta o no. Tomemos como ejemplo el caso donde deseamos implementar una tarjeta de red y queremos determinar si esta NIC va a tener una IP pública o no, a través de un parámetro. En el siguiente template, proporcionamos un parámetro llamado "**NetworkInterfaceType**" que puede ser "*Public*" o "*Privado*". Solo queremos que esta IP pública exista si el "*Tipo de interfaz de red*" es "*Público*", por lo que agregamos una condición al recurso de IP pública, de la siguiente manera:

{% highlight posh %}
{
    "apiVersion": "2017-04-01",
    "condition": "[equals(parameters('NetworkInterfaceType'),'Public')]",
    "type": "Microsoft.Network/publicIPAddresses",
    "name": "[Concat(variables('NICName'),'-pip')]",
    "location": "[resourceGroup().location]",
    "tags": {
      "displayName": "[Concat(variables('NICName'),'-pip')]"
    },
    "properties": {
      "publicIPAllocationMethod": "[parameters('IPAllocationMethod')]",
      "dnsSettings": {
        "domainNameLabel": "[Concat(variables('NICName'),'-pip')]"
      }
    }
  },
{% endhighlight %}

Muy simple: si el valor parámetro es *Public*, se generará el recurso **public IP**.

## Funciones disponibles

Dentro de las funciones que tenemos disponibles a la hora de trabajar con condiciones se encuentran:

* [equals()](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-functions-comparison#equals)
* [greater()](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-functions-comparison#greater)
* [greaterOrEquals()](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-functions-comparison#greaterorequals)
* [less()](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-functions-comparison#less)
* [lessOrEquals()](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-functions-comparison#lessorequals)

También hay otras funciones listas para utilizar, donde nos permiten comprobar los nombres de los recursos (**startWith()** o **endWith()** por ejemplo), sumar valores (**concat()**), aplicar condiciones lógicas (**and()**, **or()** y alguna más) y trabajar con números (**div()**, **add()**, **max()**, etc.). La lista de todas las funciones se encuentra aquí:

[Azure Resource Manager template functions](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-functions)

Permitiendo hacer uso de una o varias funciones, generando condiciones más complejas y que se ajustan mejor a nuestra necesidad, como por ejemplo generar un recurso específico si el largo del nombre es mayor a 6 caracteres:

{% highlight json %}
  "condition": "[greater(length(parameters('NetworkInterfaceName')),6)]"
{% endhighlight %}

Happy scripting!