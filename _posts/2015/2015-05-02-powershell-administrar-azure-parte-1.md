---
title: 'PowerShell - Administrar Azure: Parte 1'
date: 2015-05-02T10:46:49+00:00
author: Victor Silva
layout: post
permalink: /powershell-administrar-azure-parte-1/
dsq_thread_id:
  - "4585843211"
categories:
  - Azure
  - PowerShell
tags:
  - Azure
  - Cloud
  - New-AzureService
  - New-AzureVM
  - PowerShell
---
Nos encontramos en un momento que necesitamos tener conocimiento sobre las nuevas tecnologías y por sobretodo, las tecnologías de nube. Microsoft esta apostando fuertemente a Azure, por lo que es una buena oportunidad escribir algo sobre este tema. Entonces, por que no comenzar con la parte de administración de la plataforma?

Primero debemos de tener una suscripción para hacer pruebas, desde el siguiente enlace vamos a acceder a una. Simplemente necesitamos una tarjeta de credito (pero no la vamos a usar).

[Azure FREE Trial](http://azure.microsoft.com/en-us/pricing/free-trial/)

Luego de tener una suscripción debemos tener las herramientas de administración de PowerShell, para ello nos descargamos el Azure SDK para PowerShell desde el siguiente enlace:

[SDK para PowerShell](http://go.microsoft.com/?linkid=9811175&clcid=0x409)

Ahora sí, con todas las herramientas necesarias, podemos empezar a trabajar.

Como vengo del palo de infraestructura, lo primero que voy a mostrar es como crear una máquina virtual. Existen varios tipos predefinidos; con cierta capacidad de CPU y memoria, que facilitan el proceso de creación. Estos tipos ya definidos se llaman sizes. Y también tenemos la "familia" de donde proviene la máquina; esto simplemente es una categoría del sistema operativo. Estos datos los vamos a ir definiendo mas adelante.

Luego de tener lo necesario, debemos empezar a configurar nuestros datos de suscripción para poder conectarnos desde powershell a Microsoft Azure.

## Configurar conexión a la suscripción

Para comenzar debemos tener los datos para poder conectarnos desde PowerShell a la suscripción de Azure, para ello vamos a ejecutar lo siguiente:

{% highlight posh %}
Add-AzureAccount
{% endhighlight %}

Dando como resultado lo siguiente:

<img src="https://lh3.googleusercontent.com/-44QLCxQAWT4/VUYeqO91X2I/AAAAAAAAG74/DQv3AmDC3Mw/w712-h522-no/PS_Azure_Subscription_1.png" width="712" height="522" class="alignnone" />

En ese cuadro que aparece debemos ingresar la dirección de mail que ingresaron cuando dieron de alta la suscripción, y posteriormente, la contraseña.

Luego de unos momentos, nos aparecerán los siguientes datos:

<img src="https://lh5.googleusercontent.com/-sOs87btqxa8/VUYeqMo7ycI/AAAAAAAAG78/vxXkv3JPBTM/w840-h115-no/PS_Azure_Subscription_2.png" width="840" height="115" class="alignnone" />

Para corroborar que estamos conectados a la suscripción correcta, ejecutamos:

{% highlight posh %}
Get-AzureSubsctiption
{% endhighlight %}

## Crear una Máquina Virtual

Antes de comenzar tenemos que fijar los datos de la suscripción para que no nos genere error al ejecutar los comandos, para ello ejecutamos el siguiente bloque de código:

{% highlight posh %}
$Subscr = Get-AzureSubscription | select -ExpandProperty SubscriptionName
$StAccount = Get-AzureStorageAccount | select -ExpandProperty Label
Set-AzureSubscription -SubscriptionName $Subscr -CurrentStorageAccountName $StAccount
{% endhighlight %}

Debemos seleccionar la familia a la que pertenece la VM,por ejemplo si es Windows Server, Ubuntu, etc.

Podemos obtener una lista de todas las imagenes disponibles ejecutando el siguiente comando:

{% highlight posh %}
Get-AzureVMImage | select ImageFamily -Unique
{% endhighlight %}

<img src="https://lh5.googleusercontent.com/-1nK-r_9xNfc/VUDqh22vP-I/AAAAAAAAG6Y/Hoo3kgNBP1g/w644-h533-no/PS_Azure_VMfamily.png" width="644" height="533" class="alignnone" />

Para este ejemplo vamos a seleccionar la **_Windows Server Technical Preview_**.

{% highlight posh %}
$Family = "Windows Server Technical Preview"
$Image = Get-AzureVMImage | where { $_.ImageFamily -eq $Family } | sort PublishedDate -Descending | select -ExpandProperty ImageName -First 1
{% endhighlight %}

Posteriormente tenemos que definir el tamaño de la VM, existen varias configuraciones definidas de tamaños, ésta es la lista de las configuraciones:

<img src="https://lh5.googleusercontent.com/-gpmebIIvbsE/VUDir-_-P5I/AAAAAAAAG58/Ld-XI0-7amk/w279-h429-no/PS_Azure_VMsizes.png" width="279" height="429" class="alignnone" />

Para este ejemplo vamos a seleccionar la A1 que corresponde según la lista de Sizes a **_Small_**.

Por mas información, ingresar al siguiente enlace:

https://msdn.microsoft.com/library/azure/dn197896.aspx

Ya tenemos todo, es hora de unir las partes y ejecutar lo siguiente:

{% highlight posh %}
$vmName = "WindowsServerTP" #Nombre a elección para la VM
$vmSize = "Small"
$VM = New-AzureVMConfig -Name $vmName -InstanceSize $vmSize -ImageName $Image
{% endhighlight %}

También podemos agregar la credencial del usuario administrador de la máquina:

{% highlight posh %}
$vmCred = Get-Credential
$VM | Add-AzureProvisioningConfig -Windows -AdminUsername $vmCred.GetNetworkCredential().Username -Password $vmCred.GetNetworkCredential().Password
{% endhighlight %}

Creamos el Cloud Service que alojará la VM, indicando el nombre y la **Location** donde se encontrará:

{% highlight posh %}
New-AzureService -ServiceName "SvcServer" -Location "South Central US"
{% endhighlight %}

Y ahora sí, creamos la VM:

{% highlight posh %}
New-AzureVM -ServiceName "SvcServer" -VMs $VM
{% endhighlight %}

Si nos fijamos en el portal, luego de unos instantes vamos a tener la VM corriendo:

<img src="https://lh4.googleusercontent.com/-ErYl3xp8o9g/VUZz4vb-aEI/AAAAAAAAG8Q/wREEhZqF0OE/w631-h233-no/PS_Azure_VMrun.png" width="631" height="233" class="alignnone" />

Happy scripting!