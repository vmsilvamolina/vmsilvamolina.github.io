---
title: 'PowerShell - Gráficas con .Net (Parte 2)'
date: 2015-03-21T11:08:35+00:00
author: Victor Silva
layout: post
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

{% highlight posh %}
#Cargo los ensambladores necesarios
[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")

#Creo el objeto gráfica
$Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart
$Chart.Width = 400
$Chart.Height = 300

#Creo el área de la gráfica para construir
$ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
$Chart.ChartAreas.Add($ChartArea)
[void]$Chart.Series.Add("Data")

$DiskInfo = Get-WMIObject -ComputerName "vsilva" Win32_LogicalDisk | Where-Object {$_.DeviceID -eq "C:"}
$UsedPer = [math]::Round((($DiskInfo.Size - $DiskInfo.Freespace)/$DiskInfo.Size)*100)
$FreePer = 100 - $UsedPer

#Agrego los valores a la gráfica
$Dato1 = New-Object System.Windows.Forms.DataVisualization.Charting.DataPoint(0, $UsedPer)
$Dato1.AxisLabel = "$UsedPer " + "% Usado"
$Dato1.Color = [System.Drawing.ColorTranslator]::FromHtml("#A55353")
$Chart.Series["Data"].Points.Add($Dato1)
$Dato2 = New-Object System.Windows.Forms.DataVisualization.Charting.DataPoint(0, $FreePer)
$Dato2.AxisLabel = "$FreePer " + "% Libre"
$Dato2.Color = [System.Drawing.ColorTranslator]::FromHtml("#99CD4E")
$Chart.Series["Data"].Points.Add($Dato2)

#Defino la forma de la gráfica
$Chart.Series["Data"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Pie
$Chart.Series["Data"]["PieLabelStyle"] = "Disabled"

#Defino la leyenda
$Legend = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
$Legend.name = "Leyenda"
$Chart.Legends.Add($Legend)

#Defino el título
[void]$Chart.Titles.Add("Gráfica de espacio en disco C:")

#Creo el formulario e invoco
$Form = New-Object Windows.Forms.Form
$Form.Text = "PowerShell Chart"
$Form.Width = 400
$Form.Height = 340
$Form.controls.add($Chart)
$Form.Add_Shown({$Form.Activate()})
$Form.ShowDialog()
{% endhighlight %}


## Título

Lo primero que vamos a ver como podemos manipular es el título, muy importante para poder plasmar correctamente la información mas relevante. Para modificar, por ejemplo el tipo de letra, debemos agregar debajo de la línea que define el título lo siguiente:

{% highlight posh %}
[void]$Chart.Titles.Add("Gráfica de espacio en disco C:")
$Chart.Titles[0].Font = "Segoe UI Light,25pt"
$Chart.Titles[0].Alignment = "topCenter"
{% endhighlight %}

Con las 2 líneas anteriores que agregamos vamos a cambiarle el tipo de letra al título, el tamaño y la alineación. Si aparte de esto, queremos cambiar, por ejemplo el color, basta con agregar lo siguiente:

{% highlight posh %}
$Chart.Titles[0].ForeColor = "DarkBlue"
{% endhighlight %}

Podríamos declarar el color como objeto RGB de la siguiente manera:

{% highlight posh %}
$Chart.Titles[0].ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#A5A5A5")
{% endhighlight %}

## Forma

Si bien la forma mas conocida es la forma de torta, podemos con un simple cambio de código hacer que se vea de la siguiente manera:

<img src="https://lh3.googleusercontent.com/-oq5fdLbByI4/VQtPkwUsFqI/AAAAAAAAG4A/Y5Fzs78XQIk/w400-h340-no/PS_Chart2_1.png" width="400" height="340" class="alignnone" />

Debemos modificar la línea siguiente, borrando la palabra Pie y agregando la palabra Doughnut:

{% highlight posh %}
$Chart.Series["Data"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Doughnut
{% endhighlight %}

Hay que tener cuidado cuando estamos probando de cambiar las formas de las gráficas ya que no todas soportan el mismo tipo de datos iniciales, por lo que es recomendable leer el siguiente enlace a la documentación oficial, para obtener más información:

[Tipos de gráficas - MSDN (Chart Types)](https://msdn.microsoft.com/en-us/library/dd489233%28v=vs.140%29.aspx)

## Color

Si bien ya habíamos definido colores para los valores podemos restablecer a los que se generan por defecto, eliminando o comentando las siguientes líneas:

{% highlight posh %}
$Dato1.Color = [System.Drawing.ColorTranslator]::FromHtml("#A55353")
$Dato2.Color = [System.Drawing.ColorTranslator]::FromHtml("#99CD4E")
{% endhighlight %}

O simplemente probar colores nuevos para los valores. La idea es poder experimentar lo que mas nos gusta o que mejor encaja a nuestros requerimientos.

Podemos hacer una prueba de cambiar a la forma **_Pyramid_** y borrarle los colores que definimos, quedando de la siguiente manera:

<img src="https://lh3.googleusercontent.com/-xM6EDhXPzM4/VQtTXDrJ1HI/AAAAAAAAG4Q/NQYVssPGhcw/w400-h340-no/PS_Chart2_2.png" width="400" height="340" class="alignnone" />

## Leyenda

Otra variante es eliminar la leyenda de la gráfica e introducir los valores dentro del área del gráfico, esta acción se puede realizar **eliminando** las siguientes líneas:

{% highlight posh %}
$Legend = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
$Legend.name = "
Leyenda"
  
$Chart.Legends.Add($Legend)
{% endhighlight %}

## Guardar gráfica como archivo de imagen

Por último detallar la manera mas simple para guardar nuestras gráficas como archivo .jpg. Lo vamos a hacer con la siguiente línea de código:

{% highlight posh %}
$Chart.SaveImage($ImageFile,"png")
{% endhighlight %}

Como habrán podido imaginar, la variable **_ImageFile_** corresponde al nombre con el que se guardará la gráfica. En caso de no querer utilizar una variable, ingresamos el nombre dentro de comillas dobles ("").

Happy scripting!