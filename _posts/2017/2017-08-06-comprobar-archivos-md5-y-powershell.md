---
title: Comprobar archivos usando MD5 y PowerShell
date: 2017-08-06T15:00:03+00:00
author: Victor Silva
layout: post
permalink: /comprobar-archivos-md5-y-powershell/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"f3ddfbd1d649";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:89:"https://medium.com/@vmsilvamolina/comprobar-archivos-usando-md5-y-powershell-f3ddfbd1d649";}'
dsq_thread_id:
  - "6203898526"
categories:
  - PowerShell
tags:
  - cambios
  - Check
  - comprobar
  - Get-FileHash
  - Hash
  - MD5
  - PowerShell
---

Hace un tiempo tuve un requerimiento para resolver una situación particular: Comprobar archivos diariamente a modo de identificar si tuvo cambios o no durante el día. Siempre que escucho este tipo de solicitudes pienso casi que naturalmente en PowerShell, no se me pasa por la cabeza contemplar otra herramienta. Por ello es escribo esta entrada, para hablar de MD5 y PowerShell.

## Introducción a MD5

Obviamente que antes de comenzar a escribir nuestro script vamos a hacer una pequeña introducción a MD5. MD5 es un algoritmo que proporciona un código. Este código está asociado a un archivo o un texto concreto. De esta forma, a la hora de descargar un archivo en particular el código generado por el algoritmo, también llamado hash, viene “unido” al archivo en cuestión.

Un ejemplo de uso es el mundo de las descargas de software; para comprobar que el archivo no ha sido alterado, los desarrolladores (en la mayoría de los casos) adjuntan los códigos de los archivos para que las personas puedan comprobar que el archivo no fue alterado.

## MD5 y PowerShell

En PowerShell tenemos una cmdlet que nos permite obtener el hash y se llama _Get-FileHash_.Para utilizarla basta con ejecutarla indicando el nombre del archivo y el tipo de algoritmo, por ejemplo:

{% highlight posh %}
Get-FileHash -Path C:\File.txt -Algorithm MD5
{% endhighlight %}
    

<img src="https://0lzg6w-ch3302.files.1drv.com/y4mvpQg_N0YV6EX2M6YhGzWPMdl2eOrtlrB2Y_IWSty9B2K96qz_lSbPkLk-_mX9WTphFy203f5Ur6h1d9WF64FGEeJfYEk_gyuwIlUfZDIR81gym7PJeciwoMlXWJJ2hlYZ9BSByUF0lXZC0a5bknxsjKzyhKMS_lik1gROqAksHemRYO0ZLjSVhVYnY1IhegxclHj-9OyJubZ9F422RaS7Q?width=859&#038;height=196&#038;cropmode=none" width="859" height="196" alt="MD5 y PowerShell" class="alignnone size-full" />

Resta seguir resolviendo nuestro problema y para ello es necesario comprobar que al modificar el archivo se haya modificado el HASH. Es así que vamos a modificar nuestro archivo de texto y comprobar con el resultado anterior, el nuevo valor. Todo esto lo vamos a hacer desde la consola, de la siguiente manera:

{% highlight posh %}
$oldHash = (Get-FileHash C:\File.txt -Algorithm MD5).Hash
$oldHash
echo Hola! > C:\File.txt
$newHash = (Get-FileHash C:\File.txt -Algorithm MD5).Hash
$newHash
if ($oldHash -ne $newHash) {Write-Host "Cambiaron!!" -ForegroundColor Cyan}
{% endhighlight %}

<img src="https://0lzh6w-ch3302.files.1drv.com/y4mbFZk9U6bDHPeMXDFgRw-Y8-hoZJsFpLKi7ygZq64EuBYvZstN0n4T_NP92m-nm0mHnzztSnqAUszKyvTwtIQowTU9IqvEAdtwudxm8zGdWU0Qejg0lAG5y-15tLr6K10zBhOTPceWQf9KQt5aT_WjsD-jgYgtKVLsIlpoh9P6KBBobziCqscXchfw6uqnfzBHqmvSc2HDh9IM1YD973egA?width=859&#038;height=233&#038;cropmode=none" width="859" height="233" alt="Get-FileHash" class="alignnone size-full" />

Y ahí vemos el cambio del valor! Por ahora todo resulta según lo planeado. Ahora tenemos que agarrar lo que hemos aprendido y armar un script.

## Reuniendo todo

Lo primero que tenemos que hacer es generar un archivo auxiliar para poder guardar los valores que necesitamos comparar luego. El archivo va a funcionar como una base de datos. Posteriormente debemos ejecutar la comprobación de los archivos a auditar, para luego ir revisando cada valor correspondiente a cada archivo, si tuvo alguna modificación o no. Luego de esta comprobación, es necesario que se genere una base auxiliar (por ejemplo un array) para poder enviar esa información por mail.

Adjunto el script completo, con comentarios para dejar en claro cada acción:

<script src="https://gist.github.com/vmsilvamolina/7d53d90a3d189b5b2e79fd4beb4802c5.js"></script>

Happy scripting!