---
title: '¿Cómo bloquear la creación en Azure de cualquier recurso con Azure Policy?'
author: Victor Silva
date: 2023-02-03T21:43:52+00:00
layout: single
permalink: /azure-policy-deny-all/
excerpt: ''
categories:
  - Azure
tags:
  - Azure
  - Azure Policy
---

Este artículo tiene un origen bastante particular, ya que son pocos los escenarios en donde se requerirá bloquear la creación de todos los recursos en Azure. Azure Policy permite ... En mi caso, la necesidad radicaba en una limpieza de recursos y subscriptions por lo que era necesario eviar la modificación/creación de recursos en Azure. 


## Azure Policy y las definiciones existentes

Desde el portal de Azure, si navegamos hasta el servicio de Policy (o usamos la barra de busqueda),



En la página Definiciones, busque la política "Tipos de recursos no permitidos" y haga clic en los puntos suspensivos junto a la política para seleccionar "Definición duplicada". Aquí es donde realizará los cambios necesarios en la definición de política predeterminada.
duplicar

Como puede ver, la política tiene un parámetro que le permite determinar qué recursos denegar. Dado que negaremos todos los recursos en este caso, el parámetro no es necesario.
definición original

La definición editada, que se muestra a continuación, tendrá una acción de denegación en todos los recursos como el tipo "Microsoft.*". Después de realizar el cambio y seleccionar otras opciones (ubicación, nombre, categoría), guarde la nueva definición de política. Llamé a esta política "Denegar todos los tipos de recursos".
nueva definición

El último paso es asignar la política. Esto se puede hacer haciendo clic en los puntos suspensivos junto a la nueva definición de política denegar todo y seleccionando asignar.
asignar política

Ahora que la política está asignada, se denegará cualquier intento de crear un recurso, como muestra el siguiente ejemplo.

Hay una serie de políticas integradas en Azure. Encontré dos que estaban cerca de lo que necesitaba: tipos de recursos permitidos y tipos de recursos no permitidos. Como habrás adivinado, la política de "Tipos de recursos permitidos" te permite especificar qué recursos están permitidos. Y la política de "Tipos de recursos no permitidos" le brinda la posibilidad de especificar qué recursos no se pueden crear. La "política no permitida" es más adecuada para lo que estaba tratando de lograr, sin embargo, una limitación es el requisito de seleccionar recursos individualmente de una lista de cientos. Además, no hay opción para seleccionar todo. Obviamente eso no funcionará, ya que mi paciencia no es ilimitada. Como resultado, decidí duplicar la política y hacer un pequeño cambio en su código JSON de definición.

Aquí se explica cómo duplicar la política. En Azure Portal, busque Política. Después de seleccionar Política, haga clic en Definiciones en la barra lateral debajo de Autoría.


Happy scripting!