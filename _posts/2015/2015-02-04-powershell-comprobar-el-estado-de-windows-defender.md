---
title: 'PowerShell - Comprobar el estado de Windows Defender'
date: 2015-02-04T23:37:17+00:00
author: Victor Silva
layout: post
permalink: /powershell-comprobar-el-estado-de-windows-defender/
dsq_thread_id:
  - "4499714297"
categories:
  - PowerShell
  - Windows
tags:
  - Definición de Virus
  - PowerShell
  - Script
  - Status
  - Windows Defender
---
Hace tiempo que tenía en mente tratar de resolver este tema, ya que en alguna oportunidad me hubiese sido muy útil. Me puse a investigar un poco y pude armar algo bastante aceptable y quiero compartirlo.

Para atacar el problema lo primero que traté de imaginar es que información me brinda el equipo local para poder utilizar en el script. Obviamente que fui derecho al registro de Windows y ahí encontré lo que buscaba. Si nos situamos en la ruta:

> HKLM:\Software\Microsoft\Windows Defender\SignatureUpdates

Podemos observar las siguientes claves que contienen información relevante para nosotros:

<img src="https://lh3.googleusercontent.com/-NY5S6ZxRbzs/VNLIEtHfNdI/AAAAAAAAGz0/GOHRVNGkOLY/w635-h543-no/CheckDefender_PS_2.png" width="635" height="543" class="alignnone" />

Si prestan atención esos números son los que indican la versión de la definición de Virus y Spyware que actualmente se encuentra instalada en nuestro equipo (basta con abrir desde el panel de control Windows Defender y revisar la pestaña Update):

<img src="https://lh3.googleusercontent.com/-7vR2l-BRi4A/VNLInwaT7kI/AAAAAAAAG0E/Ou-AGGFSOEY/w631-h443-no/CheckDefender_PS_3.png" width="631" height="443" class="alignnone" />

Hasta ahí vamos bien, pero de donde obtengo ese número? Existe referencia hacía él? Google me resolvió estas preguntas enseguida, dentro de los resultados de búsqueda aparece un sitio de Microsoft (**_Malware Protection Center_**) que brinda información sobre la última revisión liberada, asi como las versiones anteriores. Gol! Con estos datos, podemos empezar a crear algo&#8230;

<img src="https://lh5.googleusercontent.com/-9m7pS3Hmo0A/VNLIEvus1PI/AAAAAAAAGzw/lrYz1G_Egac/w593-h345-no/CheckDefender_PS_1.png" width="593" height="345" class="alignnone" />

(Aunque no me crean, cuando saqué la captura de pantalla, ya habían liberado otra definición nueva, por eso no coincide con la de las capturas anteriores)

Ya que los datos se encuentran en una web, que mejor que llamar a nuestro amigo **_Invoke-WebRequest_** para estos casos.

Ahora pasemos a armar el script:

Lo primero, debemos obtener los datos de las versiones para chequear con las de nuestro equipo local, usando el comando Invoke-WebRequest y manipulando la salida de los datos podremos obtener una lista con las últimas 20 versiones (que son las que mantienen publicadas) de definiciones:

{% highlight posh %}
$Web = Invoke-WebRequest –Uri http://www.microsoft.com/security/portal/definitions/whatsnew.aspx
$Lista = $Web.ParsedHTML.getElementsByTagName("option") | select InnerText
{% endhighlight %}

Seleccione la etiqueta "option", ya que es la que enlista la sversiones seguún el código fuente de la web (pulsar _Ctrl + U_ o clic derecho / _Inspeccionar elemento_ ).

Con las líneas anteriores, obtengo una variable llamada $Lista que contiene las últimas 20 definiciones de Virus de Windows Defender.

Ahora Necesito definir indicadores para saber si nuestro software local se encuentra actualizado o no. Para ello pensé en tres etapas:

- Actualizado: Última definición publicada
- Actualizaciones disponibles: No es la última,pero tampoco supera las 3 versiones anteriores
- Desactualizado: Mas viejo que 3 definiciones

El código para esto es:

{% highlight posh %}
$LastDefinition = $Lista[0].innerText
$UmbralDefinition = $Lista[2].innerText
{% endhighlight %}

Y para comprobar luego defino una función condicional. Ahora voy a definir la variable que contenga la información de la versión de definición del equipo local (por medio del registro de Windows):

{% highlight posh %}
$LocalDefinition = Get-ItemProperty -Path 'Registry::HKLM\SOFTWARE\Microsoft\Windows Defender\Signature Updates' -Name AVSignatureVersion | Select-Object -ExpandProperty AVSignatureVersion
{% endhighlight %}

Solo falta la función condicional según los valores, si son mayores o menores comoestablecimos al principio y que nos devuelvan en la consola el estado. Le agregué los colores del semáforo para que sea mas descriptivo:

{% highlight posh %}
If ($LocalDefinition -ge $LastDefinition) {
	Write-Host "Windows Defender acutlaizado al último update" -ForegroundColor Green
	Write-Host ""
} else {
	If ($LocalDefinition -gt $UmbralDefinition) {
		Write-Host "WindowsDefender hay nuevas definiciones" -ForegroundColor Yellow
		Write-Host ""
	} else {
		Write-Host "WindowsDefender desactualizado" -ForegroundColor Red
		Write-Host ""
	}
}
{% endhighlight %}

Y con eso sería todo! Sólo hay que ensamblarlo y ejecutarlo.

Dejo un enlace para descargarlo: [Comprobar el estado de Windows Defender](https://gallery.technet.microsoft.com/Comprobar-el-estado-de-b7a95d61)

Y el código:

{% highlight posh %}
############################################################################### 
# 
#  WindowsDefenderStatus - Victor Silva - 4/2/15 
# 
############################################################################### 
$Web = Invoke-WebRequest –Uri http://www.microsoft.com/security/portal/definitions/whatsnew.aspx 
$Lista = $Web.ParsedHTML.getElementsByTagName("option") | select InnerText 

$LastDefinition = $Lista[0].innerText 
$UmbralDefinition = $Lista[2].innerText 

$LocalDefinition = Get-ItemProperty -Path 'Registry::HKLM\SOFTWARE\Microsoft\Windows Defender\Signature Updates' -Name AVSignatureVersion | Select-Object -ExpandProperty AVSignatureVersion 

If ($LocalDefinition -ge $LastDefinition) { 
  Write-Host "Windows Defender acutlaizado al último update" -ForegroundColor Green 
  Write-Host "" 
} else { 
  If ($LocalDefinition -gt $UmbralDefinition) { 
    Write-Host "WindowsDefender hay nuevas definiciones" -ForegroundColor Yellow 
    Write-Host "" 
  } else { 
    Write-Host "WindowsDefender desactualizado" -ForegroundColor Red 
    Write-Host "" 
  } 
}
{% endhighlight %}   

Happy scripting!