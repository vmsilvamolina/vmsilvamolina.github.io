---
id: 687
title: 'PowerShell &#8211; Gráficas con .Net (Parte 2)'
date: 2015-03-21T11:08:35+00:00
author: Victor Silva
layout: post
guid: http://blog.victorsilva.com.uy/?p=687
permalink: /powershell-graficas-con-net-parte-2/
dsq_thread_id:
  - "4491099645"
categories:
  - PowerShell
tags:
  - .Net Framework
  - Chart
  - Cmdlets
  - Gráfica
  - PowerShell
---
Continuando con el tema gráficas en PowerShell con .Net ([enlace](http://blog.victorsilva.com.uy/powershell-como-crear-una-grafica/)) me gustaría describir otras formas de gráficas y de manipular y mostrar la información de las mismas.

Voy a comenzar dejando el código del post anterior para ir modificando los valores y demás:



## Título

Lo primero que vamos a ver como podemos manipular es el título, muy importante para poder plasmar correctamente la información mas relevante. Para modificar, por ejemplo el tipo de letra, debemos agregar debajo de la línea que define el título lo siguiente:

    [void]$Chart.Titles.Add("Gráfica de espacio en disco C:")
    $Chart.Titles[0].Font = "Segoe UI Light,25pt"
    $Chart.Titles[0].Alignment = "topCenter"
    

Con las 2 líneas anteriores que agregamos vamos a cambiarle el tipo de letra al título, el tamaño y la alineación. Si aparte de esto, queremos cambiar, por ejemplo el color, basta con agregar lo siguiente:

    $Chart.Titles[0].ForeColor = "DarkBlue"
    

Podriamos declarar el color como objeto RGB de la siguiente manera:

    $Chart.Titles[0].ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#A5A5A5")
    

## Forma

Si bien la forma mas conocida es la forma de torta, podemos con un simple cambio de código hacer que se vea de la siguiente manera:

<img src="https://lh3.googleusercontent.com/-oq5fdLbByI4/VQtPkwUsFqI/AAAAAAAAG4A/Y5Fzs78XQIk/w400-h340-no/PS_Chart2_1.png" width="400" height="340" class="alignnone" />

Debemos modificar la línea siguiente, borrando la palabra Pie y agregando la palabra Doughnut

    $Chart.Series["Data"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Doughnut
    

Hay que tener cuidado cuando estamos probando de cambiar las formas de las gráficas ya que no todas soportan el mismo tipo de datos iniciales, por lo que es recomendable leer el siguiente enlace a la documentación oficial, para obtener más información:

[Tipos de gráficas &#8211; MSDN (Chart Types)](https://msdn.microsoft.com/en-us/library/dd489233%28v=vs.140%29.aspx)

## Color

Si bien ya habiamos definido colores para los valores podemos restablecer a los que se generan por defecto, eliminando o comentando las siguientes líneas:

    $Dato1.Color = [System.Drawing.ColorTranslator]::FromHtml("#A55353")
    $Dato2.Color = [System.Drawing.ColorTranslator]::FromHtml("#99CD4E")
    

O simplemente probar colores nuevos para los valores. La idea es poder experimentar lo que mas nos gusta o que mejor encaja a nuestros requerimientos.

Podemos hacer una prueba de cambiar a la forma **_Pyramid_** y borrarle los colores que definimos, quedando de la siguiente manera:

<img src="https://lh3.googleusercontent.com/-xM6EDhXPzM4/VQtTXDrJ1HI/AAAAAAAAG4Q/NQYVssPGhcw/w400-h340-no/PS_Chart2_2.png" width="400" height="340" class="alignnone" />

## Leyenda

Otra variante es eliminar la leyenda de la gráfica e introducir los valores dentro del área del gráfico, esta acción se puede realizar **eliminando** las siguientes líneas:

$Legend = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
  
$Legend.name = &#8220;Leyenda&#8221;
  
$Chart.Legends.Add($Legend)

## Guardar gráfica como archivo de imagen

Por último detallar la manera mas simple para guardar nuestras gráficas como archivo .jpg. Lo vamos a hacer con la siguiente línea de código:

    $Chart.SaveImage($ImageFile,"png")
    

Como habrán podido imaginar, la variable **_ImageFile_** corresponde al nombre con el que se guardará la gráfica. En caso de no querer utilizar una variable, ingresamos el nombre dentro de comillas dobles (&#8220;&#8221;).

Saludos,