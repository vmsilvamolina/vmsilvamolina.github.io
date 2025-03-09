---
title: REST API y PowerShell para mortales
date: 2018-04-03T18:57:00+00:00
author: Victor Silva
layout: post
permalink: /rest-api-powershell/
categories:
  - PowerShell
tags:
  - REST API
  - Invoke-RestMethod
  - PowerShell
---

Hay muchos conceptos que generan confusión o escapan de nuestra zona de confort y por ello, no le dedicamos la atención necesaria para poder dominarlos. Más aún en los tiempos que corren donde los límites entre las tareas de los equipos de operaciones y desarrollo están tendiendo a desaparecer. Este es el motivo que impulsa el escribir el corriente post: quiero simplificar el uso de REST API en PowerShell.

Como mencioné en el párrafo anterior, la idea es poder exponer el concepto de REST API y su usabilidad de forma sencilla y simple para expandir nuestro conocimiento en este maravilloso mundo de la tecnología.

## API

REST API es un tipo particular de API, por ende, lo primero que se debe hacer es definir es API. Según [Wikipedia](https://es.wikipedia.org/wiki/Interfaz_de_programaci%C3%B3n_de_aplicaciones):

> La **interfaz de programación de aplicaciones**, abreviada como **API** del inglés: *Application Programming Interface*,​ es un conjunto de subrutinas, funciones y procedimientos (o métodos, en la programación orientada a objetos) que ofrece cierta biblioteca para ser utilizado por otro software como una capa de abstracción.

## REST

REST significa "Representational State Transfer", siendo esto un tipo de arquitectura de desarrollo web que se construye totalmente en el estándar HTTP. REST permite crear servicios y aplicaciones que pueden ser consumidas por cualquier cliente o dispositivo que comprenda HTTP pudiendo conectarse, consultar e incluso (en algunos casos) enviar datos. 
Generalmente, cuando se realiza una conexión con una API REST, se deberá proporcionar cierta información, que indica que acción se pretende ejecutar (llamado método).

## Código y ejemplos

Con el marco teórico anterior, es un buen momento de comenzar a ver código :)

Antes de comenzar es necesario nombrar que cmdlet ofrece PowerShell para poder trabajar sobre una API REST. El nombre de este maravilloso cmdlet es **Invoke-RestMethod** y aquí algunos ejemplos de uso:

### GET
Asumiendo que la respuesta del la consulta tiene el siguiente formato:
> { "items": [] }

Es posible extraer la información anidada de los archivos de la siguiente manera:

{% highlight posh %}
$response = Invoke-RestMethod 'http://example.com/api/files'
$files = $response.items
{% endhighlight %}

### GET + "custom headers"

{% highlight posh %}
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $headers.Add("X-DATE", '9/29/2018')
  $headers.Add("X-SIGNATURE", 'xxxxxxxxxxxxxxxxxxx')
  $headers.Add("X-API-KEY", 'testUser')
  $response = Invoke-RestMethod 'http://example.com/api/people/1' -Headers $headers
{% endhighlight %}

### PUT/POST

{% highlight posh %}
$person = @{
    title='TituloDelArchivo'
    author='Victor Silva'
  }
  $json = $person | ConvertTo-Json
  $response = Invoke-RestMethod 'http://example.com/api/files/1' -Method Put -Body $json -ContentType 'application/json'
{% endhighlight %}

### DELETE

{% highlight posh %}
$response = Invoke-RestMethod 'http://example.com/api/files/1' -Method Delete
{% endhighlight %}

Happy scripting!