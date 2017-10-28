---
id: 1210
title: El parámetro passthru en PowerShell
date: 2016-07-21T15:51:00+00:00
author: Victor Silva
layout: single
guid: http://blog.victorsilva.com.uy/?p=1210
permalink: /passthru-en-powershell/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"e32f6186c229";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:87:"https://medium.com/@vmsilvamolina/el-par%C3%A1metro-passthru-en-powershell-e32f6186c229";}'
dsq_thread_id:
  - "5237934596"
categories:
  - PowerShell
tags:
  - Cmdlet
  - parámetro passthru
  - pasthru
  - PowerShell
---
El parámetro **_passthru_** es utilizado con frecuencia, pero sin conocer realmente que es lo que permite realizar, o al menos que es lo que hace de manera simple. Básicamente permite agregar una salida a cmdlets que no tienen esta función por defecto, es decir que agrega una funcionalidad o extiende el uso de ciertos cmdlets.

Su principal uso o por lo que la mayoría de las personas utilizan el parámetro **_passthru_** es la posibilidad de verificar que es lo que hace un cmdlet en particular o que se pretende lograr como resultado.

### Usando el parámetro passthru

Todos conocemos varios cmdlets que devuelven &#8220;cosas&#8221; por defecto: los que empiezan con Get, New, Set de los módulos que manejamos a diario de seguro nos arrojan información a la consola de manera predeterminada. Pero como comentamos anteriormente, en otros no ocurren acciones de salida. Cumple lo anterior el cmdlet **_Copy-Item_**, simplemente copia el o los objetos desde el origen al destino sin acusar nada luego de finalizado, veamos un pequeño ejemplo:

    Copy-Item -Path C:\Temp\File.txt -Destination .\Desktop
    

Otro ejemplo que clarifica esta situación se presenta al utilizar el cmdlet Get-Process:

    Get-Process | Out-File C:\reports\Process.txt
    

Estos son dos ejemplos típicos de comandos que no tiene salida y que en el uso diario capaz que no es necesario tener una salida. ¿Y que sucede si en cierta situación requerimos tener un resultado? Para poder resolver el requerimiento es necesario recurrir al parámetro passthru, de la siguiente manera:

    Copy-Item -Path C:\Temp\File.txt -Destination .\Desktop -Passthru
    

Obteniendo el siguiente resultado:

<img src="https://oy9bda-ch3302.files.1drv.com/y4mP9VjxyJaeiTZgwkEkH2-I7ArwOwWGlVog332QrJ6XGTmeMGhwfgYyPoSxXncNJw2dGaRg3dIFlTSEWOA5eJjeYFkJ18YEbHe9ynyUc2bU7w_SH19SQsXAg3nxG-l1nrH3iL9aU2x7jC9RBczrkziVt0sKi1gd9bMA87Jy7gHkqalpnbe-T2XqpfboHLSmONCjgBLbUzwzSlS50dA-TujwQ?width=859&#038;height=189&#038;cropmode=none" width="859" height="189" alt="Copy-Item con el parámetro Passthru" class="alignnone size-medium" /><h3Encontrar comandos con el parámetro passthru</h3> 

Para obtener una lista con todos los cmdlets que cuentan con el parámetro _passthru_ disponibles para usar debemos ejecutar algo como la siguiente línea:

    Get-Command -PipelineVariable commands | `
    where { $_.ParameterSets.Parameters.Name -eq "PassThru" } | ForEach-Object {$commands}
    

Tomando como referencia los cmdlets disponibles según los módulos actuales en la consola.

Saludos,