---
title: "GUID único en templates ARM con PowerShell"
author: Victor Silva
date: 2018-11-09T22:21:00+00:00
layout: post
permalink: /arm-templates-guid-unico/
excerpt: "Los que hemos trabajado en Azure con ARM templates sabemos que puede tornarse difícil gestionar los diferentes recursos de un template y más aún, se vuelve un poco engorroso el tema del manejo de los GUID (Globally Unique Identifier). Estos amigos generan muchos dolores de cabeza a la hora de intentar orquestar los identificadores y que éstos sean únicos."
categories:
  - PowerShell
  - Azure
  - DevOps
tags:
  - PowerShell
  - Azure
  - ARM
  - ARM templates
  - GUID
  - DevOps
  - Automatización
---

Los que hemos trabajado en Azure con *ARM templates* sabemos que puede tornarse difícil gestionar los diferentes recursos de un template y más aún, se vuelve un poco engorroso el tema del manejo de los GUID (Globally Unique Identifier). Estos amigos generan muchos dolores de cabeza a la hora de intentar orquestar los identificadores y que éstos sean únicos.

Si bien existen varios métodos, la idea es hablar de la función **guid()**.

Según la documentación:

>This function is helpful when you need to create a value in the format of a globally unique identifier. You provide parameter values that limit the scope of uniqueness for the result. You can specify whether the name is unique down to subscription, resource group, or deployment.

>The returned value is not a random string, but rather the result of a hash function. The returned value is 36 characters long. It is not globally unique.

De lo anterior me gustaría resaltar que no devuelve un valor random, si no que el resultado es un hash de 36 caracteres.

### Paso a paso

Definir el parámetro de entrada, que toma la fecha y hora actual (UTC) en *ticks* dentro del template ARM:

{% highlight posh%}
  "parameters": {
   "_CurrentDateTimeInTicks": {
     "type": "string",
     "minLength": 18,
     "maxLength": 18,
     "metadata": {
        "description": "Fecha y hora en ticks, usado para generar un único string en cada deploy"
      }
    }
  }
{% endhighlight %}

Generar una **globally unique string** en las variables del template ARM:

{% highlight posh%}
  "variables": {
    "UniqueStringBasedOnTimeStamp": "[uniqueString(deployment().name, parameters('_CurrentDateTimeInTicks'))]",
}
{% endhighlight %}

Luego, generar el GUIDs para lo que sea requerido, por ejemplo:

{% highlight posh%}
  "name": "[guid('AzureAutomationJobName', variables('UniqueStringBasedOnTimeStamp'))]"
{% endhighlight %}

Y ahora en PowerShell, deberemos ejecutar lo siguietne para convertir la fecha actual en ticks:

{% highlight posh%}
  $UTCNow = (Get-Date).ToUniversalTime()
  $UTCTimeTick = $UTCNow.Ticks.tostring()
{% endhighlight %}

Como último paso ejecutamos el deploy del template en PowerShell, y pasamos la fecha en ticks al template:

{% highlight posh%}
  $TemplateParameters = @{
    '_CurrentDateTimeInTicks' = $UTCTimeTick
  }
  New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName  -TemplateFile $TemplateFilePath @TemplateParameters
{% endhighlight %}

Happy scripting!
