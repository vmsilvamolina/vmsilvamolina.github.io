--- 
title: "¿Cómo actualizar por PowerShell las reglas de firewall en Azure SQL? [Guest]"
author: Felipe Schneider
date: 2020-08-06T19:30:00+00:00 
layout: post 
permalink: /powershell-firewall-azure-sql/
excerpt: "Debido a la pandemia que afecta a todos en el mundo, la mayoría de los que trabajamos en TI nos vimos forzados a trabajar desde casa con un montón de desafíos. En esta entrada de blog les quiero comentar un problema que me surgió relacionado con la seguridad del lugar donde trabajo y una posible forma de solucionar ese problema de forma 'automática'."
categories: 
  - Azure
  - PowerShell
  - Guest
tags: 
  - Azure SQL
  - PowerShell
  - Firewall
---

<div>
<b>Note:</b>
Este es el primer post de invitados :)
</div>{: .notice}

Debido a la pandemia que afecta a todos en el mundo, la mayoría de los que trabajamos en TI nos vimos forzados a trabajar desde casa con un montón de desafíos. En esta entrada del blog les quiero comentar un problema que me surgió relacionado con la seguridad del lugar donde trabajo y una posible forma de solucionar ese problema de forma "automática".

## Contexto del problema

La casa matriz del cliente cuenta con una SSL/VPN para acceder a los servidores productivos, dicha VPN por temas de seguridad, no permite el uso de **Split tunneling** por lo tanto todo mi tráfico pasa a través del Gateway de la oficina. Esto genera que el consumo de dicho equipo se vea aumentado significativamente. Otro tema para tener en cuenta es que la mayoría de nosotros no contamos con una IP fija desde nuestros hogares por lo tanto cada 12hs aproximadamente se nos renueva dicha IP. Por lo tanto, lo que vamos a hacer es agregar una nueva entrada en el firewall del Azure SQL con nuestra nueva IP cada vez que se actualice (o al menos cada vez que el script corra).

## Paso a paso

El primer desafío que debemos sortear es obtener nuestra IP pública, por suerte a partir de las nuevas versiones de Windows 10, el comando [cURL](https://devblogs.microsoft.com/commandline/tar-and-curl-come-to-windows/) viene de forma nativo integrado en el kernel del OS. Existen muchos sitios que bridan el servicio de decirnos cual es nuestra IP, por la simplicidad en que presenta el dato vamos a usar [https://ifconfig.io/ip](https://ifconfig.io/ip) ya que la respuesta es la IP y no tenemos que analizar el DOM o andar parseando la respuesta mediante filtrado de etiquetas, splits u otros.

Ahora bien, si hacemos `curl ifconfig.io/ip` desde un cmd todo anda bien:

<img src="/assets/images/postsImages/PS_FW_SQL_0.png" class="alignnone">

Pero si lo hacemos desde PowerShell no tanto:

<img src="/assets/images/postsImages/PS_FW_SQL_1.png" class="alignnone">

El problema radica en que PowerShell para acelear la adaptación genero un montón de alias de comandos, cURL en este caso es un alias de `Invoke-WebRequest`:

<img src="/assets/images/postsImages/PS_FW_SQL_2.png" class="alignnone">

Si bien el comando **Invoke-WebRequest** ha mejorado grandemente desde su comienzo, sigue teniendo dificultades (que Microsoft ya se ha planteado mejorar en sus próximas versiones, por ejemplo: el manejo de credenciales temporales y/o cookies).

De nuevo en lo que estábamos, como PowerShell trabaja con objetos, vamos a hacer un ajuste a nuestra línea de código:

<img src="/assets/images/postsImages/PS_FW_SQL_3.png" class="alignnone">

Listo! Ya tenemos nuestra IP pública haciendo una asignación:

{% highlight posh%}
$NuevaIP = (curl https://ifconfig.io/ip).content
{% endhighlight %}

Lo siguiente que vamos a hacer es importar el módulo de azure en PowerShell:

{% highlight posh%}
Import-Module az
{% endhighlight %}

Y autenticarnos con nuestro usuario (idealmente el usuario y la clave podría ser almacenado en alguna suerte de value, almacén seguro como Azure Key Vault o al menos cifrado para que no se pueda leer en el script). Para este caso vamos a poner valores doomies:

{% highlight posh%}
Write-Host -ForegroundColor Green "Creamos las credenciales para autenticar"
$secpasswd = ConvertTo-SecureString "MiClaveSuperSeguraAca” -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ("miUsuario@miCompania.com", $secpasswd)
Connect-AzAccount -Credential $mycreds
{% endhighlight %}

Una vez que estamos autenticados debemos cambiarnos al contexto de nuestra suscripción para poder acceder a los recursos de la misma:

{% highlight posh%}
$subId = "miIdDeSubscripcion"
Write-Host -ForegroundColor Green "Seleccionamos la subscripcion."
Select-AzSubscription -SubscriptionId $subId
{% endhighlight %}

Lo siguiente que tenemos que hacer es obtener el objeto, en este caso como yo ya se sus datos solo los tengo que cargar (de nuevo, esto podría ser hecho desde un `archivo.config`, por ejemplo):

{% highlight posh%}
$dbName = "nombreBaseDatos"
$serverName = "nombreServidor"
$resourceGroupName = "nombreResourceGroup"
$ruleName = "nombreDeReglaQueVoyAActualizar" 
{% endhighlight %}

Por último, una vez que tenemos todos los datos cargados, vamos a actualizar nuestra regla con la nueva IP:

{% highlight posh%}
Write-Host -ForegroundColor Green "Actualizamos la regla"
Set-AzSqlServerFirewallRule -ServerName $serverName -ResourceGroupName $resourceGroupName `
  -Name $ruleName -StartIpAddress $NuevaIP -EndIpAddress $NuevaIP
{% endhighlight %}

Y ya está, ahora este script lo podemos configurar para que corra como tarea programada cada X cantidad de horas y poder acceder a nuestro azure SQL de forma directa.

## Bonus track

Este problema también nos paso con un cliente que tiene un FortiGate con un SD-WAN configurado y uno de los enlaces tiene ip dinámica. Lamentablemente para esto no pudimos usar el comando `Invoke-WebRequest`.

Para corregir y hacer que ande en este cliente hicimos lo que se detalla a continuación.

Primero corregimos el perfil de PowerShell para eliminar el alias y poder usar el cURL de forma nativa, para esto simplemente ejecutamos en un PowerShell el siguiente comando:

{% highlight posh%}
echo "Remove-Item alias:curl" > $PROFILE
{% endhighlight %}

Tener en cuenta que si ya tenemos modificado el perfil, la línea anterior nos va a sobrescribir todo el contenido.

Después debemos hacer una llamada al FortiGate para que nos de una cookie de autenticación. A partir de las versiones nuevas (creo que desde la 6.0) FortiGate soporta algunos comandos simil API (se que hay una API en desarrollo, pero por no ser partner no pude acceder a ella… mal por el trabajo cerrado no colaborativo de Forti ☹, bien por la gente que comparte info en internet y un poco de prueba y error).

Antes de seguir adelante debo comentar que esto es posible solo si el FortiGate tiene permitida la administración desde afuera, sino el script debe correr dentro de la red LAN para poder acceder la GUI de administración.

{% highlight posh%}
Write-Host -ForegroundColor Green "Vamos a autenticar contra el Forti para obtener la nueva IP"
curl -k -i -X POST https://NuestroNombre.fortiddns.com/logincheck -d "username=miUsuarioAdmin&secretkey=miClaveSuperSegura" --dump-header headers.txt -c cookies.txt
{% endhighlight %}

Una vez que tenemos nuestros cabezales con la autorización y nuestra cookie de sesión vamos a llamar a la API de FortiGate y consultar todas las interfaces (de nuevo esto podría ser mejorado a futuro teniendo alguna forma de acceder del estilo infeface/WAN1 o algo similar). Como no es posible, tuve que hacer la llamada y analizar el JSON que nos devuelve, una vez comprendido y porque no soy muy ducho con JSON es que se hace el `findstr= "ip"` para obtener las IPs de todas las inferfaces y sabiendo que el valor que busco está en la opción 3 hacer el `Split` (se podría hacer mejor, sin duda, pero anda y nada más permanente que lo que funciona):

{% highlight posh%}
Write-Host -ForegroundColor Green "Vamos a obtener ls IP para actualizar"
$ip = curl -k -i -X GET https:// NuestroNombre.fortiddns.com/api/v2/monitor/system/interface -b headers.txt | findstr "ip"
$NuevaIP = $ip[0].Split('"')[3]
{% endhighlight %}

Una vez que temenos el valor de **$NuevaIP**, retomamos el script anterior en la sección de importación del modulo de azure.

Para cerrar quería agradecer a mi amigo Victor que me presto el espacio para publicar.

<div style="display:block;float:left;padding:10px;width:100px;height:150px;">
  <img alt="Foto de perfil de Felipe Schneider" style="border-radius: 50%;width: 100px;" src="/assets/images/postsImages/perfil_Felipe.jpg">
</div>
<div style="float: left;padding: 10px;width: 250px;height: 150px;">
  <p style="margin:8px 10px;">Felipe Schneider</p>
  <p style="margin:8px 10px;"><i class="fa fa-linkedin" aria-hidden="true"></i> <a href="https://uy.linkedin.com/in/felipe-schneider-03066921">LinkedIn</a></p>
</div>
<br style="clear: both;display: table;">

Happy scripting!