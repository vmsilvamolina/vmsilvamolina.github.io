---
title: 'PowerShell - Random-ColorHex'
date: 2015-09-05T16:00:20+00:00
author: Victor Silva
layout: post
permalink: /powershell-random-colorhex/
dsq_thread_id:
  - "4472946398"
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"58971138f571";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:73:"https://medium.com/@vmsilvamolina/powershell-random-colorhex-58971138f571";}'
categories:
  - Sin categoría
tags:
  - Cmdlet
  - Colores
  - Get-Random
  - Hexadecimal
  - RGB
---
Hace poco estuve necesitando generar documentos con HTML y CSS, por lo que tuve que recurrir a, en los casos de formato, los colores hexadecimales. Como PowerShell me permite hacer casi todo lo que necesito la mayoría de las veces, me decidí a crear una función simple para poder generar colores de forma "
random"
.

Existe la función [Get-Random](https://technet.microsoft.com/en-us/library/hh849905.aspx) que me permite obtener valores sin ningún criterio aparente. Dentro de las opciones que tenemos en esta función, existe un parámetro que nos permite definir el máximo valor que puede llegar a obtener la función.

Éste parámetro es muy útil, ya que el sistema de colores [RGB](https://es.wikipedia.org/wiki/RGB) nos indica que por pixel hay 8 bits : 2 exp 8 = 256. Siendo un color representado por Rojo-Azul-Verde, tenemos que 256 x 256 x 256 = 16777216 variedades, siendo éste valor el máximo en nuestra función random.

Teniendo este valor definido, debemos representar de manera apropiada nuestro color. La manera apropieada va a ser **_#XXXXXX_**, entonces recurrimos a la definición de la siguiente función para resolver nuestro problema:

    function Random-ColorHex {
        '#{0:X6}' -f (Get-Random -Maximum 16777216)
    }
    

Si ejecutamos el código anterior, por ejemplo que nos asigne el color a la variable **$color**, debemos ingresar en la consola lo siguiente:

    $color = Random-ColorHex
    

Y si invocamos la variable, obtendremos el color en formato hexadecimal:

<img src="https://lh3.googleusercontent.com/S06HinZILjdJ7jdNMPderJlWwYCirdSlL3R0VrxiCjdMHED81Ub3kZlPTvccQrJHFdms_ycz1z92Ayuajo6qiDkhaGv31ijaBBk7gJGU3p4bg1aGt65fe9rZdwd0Lg_uTcdKJD4FbmPS109l6QRH0NB58TGSR7b9-62up63nVn-zEXvpDoEcwI4F0rk2zwoc2IxkeiDx-R8600rHyXArlhe6-L2TUeUurvdE_0w9kYVyGyM0kASxSRVW9DKMiDMH6rqhs4sy6m_Qyu24ySWbjlC6c8YLqzyTuZtK4wP6yNs7vL5ErK8fNU9I05RHCUBy32YWqb8Iiw01SyQdZ4bx9xWJ6OwyJNTVd3XnOa-uV5PIVhh1FIrZ3wfUv1eLnEMG1bP_y2VIlor-HPwpaEXusxEO5Dx5LZcBNX_7mlAkDaTjKtVydKp_7A20cCdghuAi4hg3Gsmbmns-DGj0Q62anD4m3gK0MudrD2Q2Gv3OEHT6MjfIfwD0N3S3VIz2S1iK7-CLjKcss_LubIe3eAi2a6h01kCBez4vxQSDbYFJsGU=w271-h86-no" width="271" height="86" class="alignnone" />

Saludos!