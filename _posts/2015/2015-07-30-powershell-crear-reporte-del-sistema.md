---
title: 'PowerShell - Crear reporte del sistema'
date: 2015-07-30T23:54:22+00:00
author: Victor Silva
layout: post
permalink: /powershell-crear-reporte-del-sistema/
dsq_thread_id:
  - "4473723983"
categories:
  - PowerShell
tags:
  - .Net
  - .Net Framework
  - Chart
  - Checklist
  - Get-WmiObject
  - Gráfica
  - HTML
  - Reporte
---
Un excelente uso que podemos darle a nuestro querido lengueje de scripting es la de generar reportes. A todo el mundo le gustan los reportes!!! Ya sea con colores, información detallada, gráficas, etc. Existen muchos recursos para poder generar un reporte. Hoy, quiero compartir como armar un reporte del sistema (localhost :)), en donde se muestre el estado de uso del disco (o discos) locales, uso de memoria y CPU por medio de una gráfica con .NET (para los que no se acuerdan, este tema ya lo tramamos en un [post anterior](http://blog.victorsilva.com.uy/powershell-como-crear-una-grafica/)).

Este reporte va a tener como formato de salida el lenguaje standard de la web: HTML. Si bien podemos realizarlo en otros formatos, prefiero mostrar también el proceso de armado y las cosas a tener en cuenta.

Hecha la presentación, vamos a comenzar!

Vamos a crear una función que nos genere la gráfica del uso de la memoria, para ellos vamos a utilizar la forma de **_Doughnut_**:

{% highlight posh%}
Function Create-DoughnutChart() {
  param([string]$FileName, $Used, $Free)    

  #Crea el objeto gráfica
  $Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart
  $Chart.Width = 170
  $Chart.Height = 100

  #Crea el área de la gráfica para construir
  $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
  $Chart.ChartAreas.Add($ChartArea)
  [void]$Chart.Series.Add("Data")

  #Agregar los valores a la gráfica
  $Dato1 = New-Object System.Windows.Forms.DataVisualization.Charting.DataPoint(0, $Used)
  $Dato1.AxisLabel = "$Used" + " GB"
  $Dato1.Color = [System.Drawing.ColorTranslator]::FromHtml("#A55353")
  $Chart.Series["Data"].Points.Add($Dato1)
  $Dato2 = New-Object System.Windows.Forms.DataVisualization.Charting.DataPoint(0, $Free)
  $Dato2.AxisLabel = "$Free" + " GB"
  $Dato2.Color = [System.Drawing.ColorTranslator]::FromHtml("#99CD4E")
  $Chart.Series["Data"].Points.Add($Dato2)

  #Defino la forma de la gráfica
  $Chart.Series["Data"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Doughnut
  $Chart.Series["Data"]["PieLabelStyle"] = "Disabled"

  #Leyenda
  $Legend = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
  $Legend.name = "Leyenda"
  $Chart.Legends.Add($Legend)

  #Guarda la gráfica como archivo .png
  $Chart.SaveImage($FileName + ".png","png")
}
{% endhighlight %}

Para que la gráfica anterior funcione correctamente, debemos de cargar los assemblies de .NET correspondientes. O sea que en primer lugar debemos de ingresar las siguientes líneas de códifo antes de que se empiece a declarar la función de la gráfica:

{% highlight posh%}
  [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
  [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")
{% endhighlight %}
    

Teniendo los assemblies, podemos generar una gráfica en forma de línea en el tiempo para plasmar el uso del CPU sobre el paso del tiempo. El lapso de tiempo lo vamos a definir, más adelante en el post, en una variable al comienzo del script:

{% highlight posh%}
  Function Create-LineChart {
    param([string]$FileName, $Values)
  
    #Crea el objeto gráfica
    $Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart
    $Chart.Width = 170
    $Chart.Height = 100

    #Crea el área de la gráfica para construir
    $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
    $ChartArea.AxisX.Title = "Tiempo (s)"
    $ChartArea.AxisX.Interval = 5
    $ChartArea.AxisY.Interval = 10
    $ChartArea.AxisY.LabelStyle.Format = "{#}%"
    $Chart.ChartAreas.Add($ChartArea)
    [void]$Chart.Series.Add("Data")

    #Agrega los valores a la gráfica
    $Chart.Series["Data"].Points.DataBindXY($Values.Keys, $Values.Values)

    #Defino la forma de la gráfica
    $Chart.Series["Data"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
    $Chart.Series["Data"].BorderWidth = 3
    $Chart.Series["Data"].Color = "#3A539B"

    #Guarda la gráfica como archivo .png
    $Chart.SaveImage($FileName + ".png","png")
  }
{% endhighlight %}

Continuando con las secciones importantes, pasamos a la extracción y recolección de los datos. Si bien voy a dejarles el bloque de código ya con la solución, megustaría que lo lean y lo entiendan (la mayoría de las cosas están comentadas)

{% highlight posh%}
## Información de discos ##
$DiskInfo = Get-WMIObject -Class 'Win32_LogicalDisk' -ComputerName $Computer  | Where-Object {$_.DriveType -eq 3}  `
  | Select-Object @{Name="Unidad";Expression={($_.Name)}},
                  @{Name="Total (GB)";Expression={([math]::Round($_.size/1gb))}},
                  @{Name="Libre (GB)";Expression={([math]::Round($_.freespace/1gb))}},
                  @{Name="% Uso";Expression={(100-([math]::Round($_.freespace/$_.size*100)))}},
                  @{Name="Grafica de uso";Expression={
                    $UsedPer= (($_.Size - $_.Freespace)/$_.Size)*100
                    $UsedPer = [math]::Round($UsedPer)
                    $UsedGraph = $Char * (($UsedPer * 20 )/100)
                    $FreeGraph = $Char * (20-(($UsedPer * 20 )/100))
                    "xopenspan style=xcomillascolor:#A55353xcomillasxclose{0}xopen/spanxclosexopenspan style=xcomillascolor:#99CD4Excomillasxclose{1}xopen/spanxclose" -f $UsedGraph,$FreeGraph}} | ConvertTo-HTML -fragment
#Reemplazo de caracteres...
$DiskInfo = $DiskInfo -replace "xopen","<"
$DiskInfo = $DiskInfo -replace "xclose",">"
$DiskInfo = $DiskInfo -replace "xcomillas",'"'
## Información de memoria ##
$SystemInfo = Get-WmiObject -ComputerName $Computer -Class Win32_OperatingSystem  | Select-Object Name, TotalVisibleMemorySize, FreePhysicalMemory
$TotalRAM = [Math]::Round($SystemInfo.TotalVisibleMemorySize/1MB, 1)
$FreeRAM = [Math]::Round($SystemInfo.FreePhysicalMemory/1MB, 1)
$UsedRAM = $TotalRAM - $FreeRAM
Create-DoughnutChart -FileName ((Get-Location).Path + "\GraficaMemoria-$Computer") -Used $UsedRAM -Free $FreeRAM
## Información de CPU ##
$CPUtotal = @{}
for ($i=1; $i -le $CPUtime; $i++) {
  Start-Sleep -Seconds 1
  $CPU = Get-WmiObject -Class win32_processor -ComputerName $Computer | select LoadPercentage -ExpandProperty LoadPercentage -First 1
  $CPUtotal.Add($i, $CPU)
}
Create-LineChart -FileName ((Get-Location).Path + "\GraficaCPU-$Computer") -Values $CPUtotal
{% endhighlight %}

Ahora bien, nos está faltando unir las partes y generar el HTML, para ello simplemente tenemos que pensar en el archivo HTML como si fuese texto, por lo que para definir una cadena de caracteres que contiene varias líneas lo debemos hacer de la siguiente manera:

{% highlight posh%}
  $stringConVariasLineas = @" Hola soy una
  cadena de caracteres
  que tiene
  varias 
  lineas
  @"
{% endhighlight %}

Dejo a continuación el script entero, para que se pueda entender el concepto y como se resolvió la situación según lo anterior. Aproveché la situación y le di un poco de color y formato para que quede más lindo!!

<script src="https://gist.github.com/vmsilvamolina/f5f18fd2742ac876bdc1.js"></script>
  
Happy scripting!