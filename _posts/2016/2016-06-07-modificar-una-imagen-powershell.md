---
title: Modificar una imagen con PowerShell
date: 2016-06-07T10:09:38+00:00
author: Victor Silva
layout: post
redirect_from: /modificar-una-imagen-powershell/
permalink: /modificar-imagen-powershell/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"ed0b200ce0d2";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:82:"https://medium.com/@vmsilvamolina/modificar-una-imagen-con-powershell-ed0b200ce0d2";}'
dsq_thread_id:
  - "4960672346"
categories:
  - PowerShell
tags:
  - BMP
  - Draw
  - Drawing
  - FillPolygon
  - FillRectangle
  - PowerShell
---
Modificar una imagen con PowerShell es una de las cosas que quiero compartir ya que puede ser muy útil, como por ejemplo, en reportes.

## Crear una imagen

Para crear una imagen desde PowerShell vamos a ejecutar lo siguiente:

{% highlight posh%}
  #Cargo las librerías necesarias    
  Add-Type -AssemblyName System.Drawing
  
  $Filename = "$HOME\Imagen.png" 
  $Bmp = New-Object System.Drawing.Bitmap(250,250)
  $BrushBackGround = [System.Drawing.Brushes]::Red
  $Graphics = [System.Drawing.Graphics]::FromImage($Bmp)
  $Graphics.FillRectangle($BrushBackGround,0,0,$Bmp.Width,$Bmp.Height)
  $Graphics.Dispose() 
  $Bmp.Save($Filename)
  
  #Abro la imagen
  Invoke-Item $Filename
{% endhighlight %}

Con todo el código anterior, generamos una imagen en la raíz de nuestro perfil, con el nombre **_Imagen.png_** que básicamente es un cuadrado de color rojo.

Ok, no es mucho, pero al menos solo usamos la consola 😉

Vamos a ver como agregar texto a nuestra dibujo anterior.

## Añadir texto

Para agregar texto debemos ingresar, por ejemplo:

{% highlight posh%}
  $Font = New-Object System.Drawing.Font('Consolas',18)
{% endhighlight %}
    

Y digo por ejemplo, porque en realidad se podría elegir otra fuente y otro tamaño. Habiendo definido la fuente y el tamaño, vamos a definir el color:

{% highlight posh%}
  $BrushFont = [System.Drawing.Brushes]::White
{% endhighlight %}  

Y luego el texto a ingresar y su posición:

{% highlight posh%}
  $Graphics.DrawString('Hello World',$Font,$BrushFont,50,50)
{% endhighlight %}
    

Todo junto quedaría en este orden:

{% highlight posh%}
  Add-Type -AssemblyName System.Drawing
  
  $Filename = "$HOME\Imagen.png" 
  $Bmp = New-Object System.Drawing.Bitmap(250,250)
  #Creo el objeto fuente, con el tipo y tamaño
  $Font = New-Object System.Drawing.Font('Consolas',18)
  $BrushBackGround = [System.Drawing.Brushes]::Red
  #Asigno el color correspondiente al texto
  $BrushFont = [System.Drawing.Brushes]::White
  $Graphics = [System.Drawing.Graphics]::FromImage($Bmp) 
  $Graphics.FillRectangle($BrushBackGround,0,0,$Bmp.Width,$Bmp.Height)
  #Defino el texto y lo ubico en el cuadrado que dibujamos
  $Graphics.DrawString('Hello World',$Font,$BrushFont,50,100) 
  $Graphics.Dispose() 
  $Bmp.Save($Filename)
  
  Invoke-Item $Filename
{% endhighlight %}

## Crear un círculo

Solo agregando 2 líneas podemos dibujar un círculo:

{% highlight posh%}
  $BrushCircle = [System.Drawing.Brushes]::Green
  $Graphics.FillEllipse($BrushCircle, 50, 0, 80, 80)
{% endhighlight %}

## Polígono

Para crear un polígono vamos a necesitar lo siguiente:

{% highlight posh%}
  $BrushPolygon = [System.Drawing.Brushes]::Green
  $PointsNumber = 5
  $PolygonPoints = @()
  For ($i=1; $i -le $PointsNumber; $i++) {
    $Point = New-Object System.Drawing.Point ((Get-Random -minimum 0 -maximum $Bmp.Width), (Get-Random -minimum 0 -maximum $Bmp.Height))
    $PolygonPoints += $Point
  }
  $Graphics.FillPolygon($BrushPolygon, $PolygonPoints)
{% endhighlight %}

Obteniendo como resultado, algo así:

<img src="https://lh3.googleusercontent.com/0QTCdgloKpc37LVqE4Gy3MS8RDRGAK9VbzP1dhrjehWrJ8Grrrk5hpiSUrvzi2_mjOlpAxIQ9qesgobANWZOPBvZDQD0ec1yz_AygPiNWVOWuPOT-G4rrEepiIWuZPEda9CQb_i8uSBa_xW9QAf3ST0biV8-AzrFFMdHVwZVLAYXLaO7ZPKU-Pd2o8ZNl3HxVq_qBmZSJgm1eTgC1DSc4h_ekqd91WXVkcvP5rL-tjqAJZxx9A9eSBA2EQ1aIPjZnZ_4C5LPA2hPeo4weZpTUXSLmLYss7MH92Y6giNL9SXN6a91KgczqUJrf_u_HCtIN6irlmn5JtaENpv8mmhTBxBOwp7dK0uZK7fuGklr1jjNS6ehYhOcWlOebzyw8_fGwZ5NoPu7ymVJiPrsaUnG_vS1RciP2Zrb0fodLflAcSY7mo6pT8GyZX8zEjziYcliiIm29xPHCAGZsWK6WnVjsYf1Ygf1_EGuDfQlNswSL9JgGof9Yf4EwcCN4uF1N3Teg44MHzke_H62cUQespWhdGEGIE8SdlCkuGMih2jryNZjTereBYG94i-MPyuWF72nhX1bzLEsqOo-mTbROe6z4hVxCtKLHhg=s250-no" width="250" height="250" alt="Polígono dibujado" class="alignnone" />

Happy scripting!
