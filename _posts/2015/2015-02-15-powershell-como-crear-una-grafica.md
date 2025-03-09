---
title: 'PowerShell - Cómo crear una gráfica con .Net Framework'
date: 2015-02-15T09:21:46+00:00
author: Victor Silva
layout: post
permalink: /powershell-como-crear-una-grafica/
dsq_thread_id:
  - "4530750455"
categories:
  - PowerShell
tags:
  - .Net
  - Chart
  - Cmdlets
  - Gráfica
  - PowerShell
  - Scripts
---
Básicamente voy a describir cómo podemos hacer para plasmar nuestros datos de una manera más bonita, así como también poder presentarlos de una manera más apropiada y ordenada.

Primeramente lo que debemos tener en nuestro equipo es .Net Framework (si tienen Windows 8.1 no tienen que hacer nada).

Ok, empecemos. Lo primero es identificar que necesitamos para nuestras gráfica, o a partir de ahora, charts. Un chart se define por 3 objetos a grueso modo:

  * El objeto **chart** en sí, donde se van a alojar los datos y demás
  * El objeto **chart area**, que es el espacio donde se plasmará la información
  * El objeto **datapoint**; los datos en sí

Con estos tres elementos tendríamos conformada nuestra gráfica

Para hacerlo en PowerShell, debemos de ejecutar las siguientes líneas de código:

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
{% endhighlight %}

Fácil,no? Ahora debemos de agregar los datos. Primero tenemos que saber que vamos a graficar y de qué manera. Vamos a simular una gráfica tipo torta (el nombre en realidad es _pie_) del porcentaje de disco utilizado y libre. Estos datos los obtenemos de los siguientes comandos:

{% highlight posh %}
$DiskInfo = Get-WMIObject -ComputerName "vsilva" Win32_LogicalDisk | Where-Object {$_.DeviceID -eq "C:"}
$UsedPer = [math]::Round((($DiskInfo.Size - $DiskInfo.Freespace)/$DiskInfo.Size)*100)
{% endhighlight %}


La variable **$UsedPer** me indica el porcentaje usado de nuestro disco _C:_ Defino otra variable que contenga el valor del porcentaje libre:

{% highlight posh %}
$FreePer = 100 - $UsedPer
{% endhighlight %}

Ahora debemos de agregar este valor al datapoint del chart:

{% highlight posh %}
#Agrego los valores a la gráfica
$Dato1 = New-Object System.Windows.Forms.DataVisualization.Charting.DataPoint(0, $UsedPer)
$Dato1.AxisLabel = "$UsedPer " + "% Usado"
$Dato1.Color = [System.Drawing.ColorTranslator]::FromHtml("#A55353")
$Chart.Series["Data"].Points.Add($Dato1)
$Dato2 = New-Object System.Windows.Forms.DataVisualization.Charting.DataPoint(0, $FreePer)
$Dato2.AxisLabel = "$FreePer " + "% Libre"
$Dato2.Color = [System.Drawing.ColorTranslator]::FromHtml("#99CD4E")
$Chart.Series["Data"].Points.Add($Dato2)
{% endhighlight %}

Sólo quiero comentarles que agregué un color a cada valor para que quede más vistoso (en las líneas de código pueden identificar el color en formato hex ya que al comienzo tiene el símbolo #), sino queremos definir un color en particular no es necesario, el sistema proporciona 2 valores por defecto. Yo simplemente quise mostrar una manera para poder determinar los colores de los valores.

Ahora pasamos a definir la forma de nuestra gráfica, en este caso vamos a crear una del tipo pie, por lo que debemos detallar:

{% highlight posh %}
#Defino la forma de la gráfica
$Chart.Series["Data"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Pie
$Chart.Series["Data"]["PieLabelStyle"] = "Disabled"
{% endhighlight %}

La última línea de código me indica que se deshabilito la proporción de los datos en la gráfica (en otros ejemplos vamos a ver como agregar y modificar estos datos). Esto se debe a que en nuestro gráfico vamos a mostrar la información por medio de una leyenda, con las siguientes líneas:

{% highlight posh %}
#Defino la leyenda
$Legend = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
$Legend.name = "Leyenda"
$Chart.Legends.Add($Legend)
{% endhighlight %}

También vamos a agregarle un título:

{% highlight posh %}
#Defino el título
[void]$Chart.Titles.Add("Gráfica de espacio en disco C:")
{% endhighlight %}

Ya tenemos casi todo listo, ahora debemos de "exportarla" de alguna manera. Para continuar con el ejemplo, vamos a generar la gráfica en un formulario de Windows, debemos escribir:

{% highlight posh %}
#Creo el formulario e invoco
$Form = New-Object Windows.Forms.Form
$Form.Text = "PowerShell Chart"
$Form.Width = 400
$Form.Height = 340
$Form.controls.add($Chart)
$Form.Add_Shown({$Form.Activate()})
$Form.ShowDialog()
{% endhighlight %}

Ok, si estamos en Windows PowerShell ISE, simplemente ejecutamos F5, y nos debería de aparecer algo como esto:

<img src="https://lh5.googleusercontent.com/-tm9GK0GxDUg/VPcC7J6rMoI/AAAAAAAAG1Y/qtGWWf33h6I/w400-h340-no/PS_Chart_1.png" width="400" height="340" class="alignnone" />

Excelente, no?

En próximas entregas voy a seguir modificando y agregando detalles a las gráficas.

Happy scripting!