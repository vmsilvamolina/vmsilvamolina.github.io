---
title: 'Crear una instancia de EC2 en AWS con PowerShell'
author: Victor Silva
date: 2022-04-14T01:03:56+00:00
layout: post
permalink: /instancia-EC2-AWS-PowerShell/
excerpt: 'Todo el mundo sabe que este blog está a favor de las línea de comando. Con la CLI, los administradores pueden controlar los recursos de AWS desde la consola y escribir scripts de automatización. AWS tiene sus comandos para poder integrarse a PowerShell y poder sacarle jugo a la consola.'
categories:
  - AWS
  - EC2
  - PowerShell
tags:
  - AWS
  - EC2
  - PowerShell
  - Virtual Machines
---

Todo el mundo sabe que este blog está a favor de las línea de comando. Con la CLI, los administradores pueden controlar los recursos de AWS desde la consola y escribir scripts de automatización. AWS tiene sus comandos para poder integrarse a PowerShell y poder sacarle jugo a la consola.

A modo de ejemplo, vamos a desplegar una instancia de EC2 mediante PowerShell, donde hablaremos de los requisitos previos a tener en cuenta y las dependencias necesarias para llevar a cabo esta tarea.

## Prerequisitos

Lo primero, y fundamental, es contar con una cuenta de AWS para poder desplegar los recursos necesarios. En caso de no contar con ninguna, desde el siguiente enlace se puede generar una gratuita: [AWS Free Tier](https://aws.amazon.com/free/)

Debemos generar un usuario con privilegios, que vamos a usar durante el procedimiento. Para ello se encuentra el siguiente link a la documentación: [Create an administrative user - AWS](https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-set-up.html#create-an-admin)

Ya habiendo generado el usuario, vamos a crearle una key de acceso. Desde el portal web (https://aws.amazon.com/console), seleccionamos el usuario creado en **IAM** y luego vamos a la sección `Create access key`.

<img src="/assets/images/postsImages/AWS_POSH_EC2_1.png" class="alignnone">

De las opciones disponibles, vamos a elegir `Command Line Interface (CLI)`, ingresamos una descripción y listo! Tenemos la clave y el secret.

<img src="/assets/images/postsImages/AWS_POSH_EC2_2.png" class="alignnone">

> Recordar que estos valores aparecen una única vez, si bien es posible descargar un archivo .csv, lo ideal es poder guardarlos de forma segura por temas de seguridad.

## PowerShell, yo te elijo!

Desde nuestra querida consola de PowerShell vamos a instalar el módulo corespondiente para poder trabajar con AWS:

{% highlight posh%}
Install-Module -Name AWS.Tools.Installer
Install-AWSToolsModule AWS.Tools.EC2, AWS.Tools.SimpleSystemsManagement
{% endhighlight %}

Ingresar la letra "A" desde el teclado para aceptar la instalación del módulo y el uso de la _PowerShell Gallery_ como fuente de los recursos necesarios.

### Perfil de usuario

Ya con todo lo necesario, el siguiente punto es inicializar las credenciales de AWS por medio del comando **Initialize-AWSDefaultConfiguration** donde a su vez, será necesario declarar los siguientes parámetros:

* AccessKey
* SecretKey
* Region

AccessKey y SecretKey son los valores que obtuvimos anteriormente desde el portal web. En lo que respecta a la región, es necesario ingresar una para que sea la predeterminada al momento de desplegar recursos por medio de éste perfil de usuario. Para obtener la lista de las regiones disponibles:

{% highlight posh%}
Get-AWSRegion
{% endhighlight %}

Para el ejemplo en curso, se ha determinado la región "us-east-1":

{% highlight posh%}
Initialize-AWSDefaultConfiguration -AccessKey "XXXXX" -SecretKey "YYYYY" -Region "us-east-1"
{% endhighlight %}

Perfecto! Credenciales generadas localmente. Sigamos adelante...
## Dependencias necesarias

Antes de poder crear la instancia EC2, se deben tener varios recursos ya creados con anterioridad. Al ser un procedimiento introductorio, vamos a crear todas las dependencias y así obtener una visión más global de los recursos involucrados.

Para crear la configuración mínima para implementar y acceder a una instancia EC2, se necesita una nube privada virtual (en inglés: Virtual Private Cloud o **VPC**) con una subred, ciertos componentes de red y la propia instancia EC2.

### VPC

¿Cómo creamos una nueva VPC? Primero se deberá definir un espacio de direcciones con la notación del standard de "_enrutamiento entre dominios sin clases_" (en inglés: Classless Inter-Domain Routing o **CIDR**):

{% highlight posh%}
$vpcCIDR = "10.0.0.0/16"
{% endhighlight %}

Y luego, ya podemos crear la VPC con el comando `New-EC2Vpc`:

{% highlight posh%}
$vpc = New-EC2Vpc -CidrBlock $vpcCidr
{% endhighlight %}

Por defecto, una VPC de AWS no tiene ningún DNS configurado, por lo que es necesario habilitarlo para que pueda ser utilizado por cualquier instancia que se ejecute dentro:

{% highlight posh%}
Edit-EC2VpcAttribute -VpcId $vpc.VpcId -EnableDnsSupport $true
{% endhighlight %}

Es posible que desee resolver públicamente los nombres de host de las instancias EC2. Para ello, se puede habilitar con lo siguiente:

{% highlight posh%}
Edit-EC2VpcAttribute -VpcId $vpc.VpcId -EnableDnsHostnames $true
{% endhighlight %}

### Recursos de red

A continuación, debemos agregar un par de recursos de red para garantizar que la nueva instancia EC2 tenga acceso a Internet y que sea posible conectarnos a la misma. Estos recursos incluyen un internet gateway, una ruta a la route table y una subred dentro del espacio de direcciones de la VPC.

Un _internet gateway_ es lo que permite que una VPC se comunique con Internet. Primero que nada, creamos uno de la siguiente manera:

{% highlight posh%}
$internetGateway = New-EC2InternetGateway
{% endhighlight %}

Luego, debemos asociarlo a la VPC:

{% highlight posh%}
Add-EC2InternetGateway -InternetGatewayId $internetGateway.InternetGatewayId –VpcId $vpc.VpcId
{% endhighlight %}

Si desea que los nodos de la red, incluida la instancia EC2, sepan cómo enrutar a Internet, necesita una tabla de enrutamiento y una ruta:

{% highlight posh%}
$routeTable = New-EC2RouteTable -VpcId $vpc.VpcId
{% endhighlight %}

Agregamos una ruta predeterminada:

{% highlight posh%}
New-EC2Route -GatewayId $internetGateway.InternetGatewayId -RouteTableId $routeTable.RouteTableId -DestinationCidrBlock '0.0.0.0/0'
{% endhighlight %}

<img src="/assets/images/postsImages/AWS_POSH_EC2_3.png" class="alignnone">

Dado que la ruta predeterminada es la única ruta que está agregando a la tabla de rutas, todo el tráfico pasa por el internet gateway. Se puede modificar esta regla o agregar más reglas, dependiendo de la necesidad. 

Para crear una subred dentro de la subred de la VPC, primero busque una availability zone para crearla. El siguiente comando da como resultado la lista de todas las zonas disponibles en la región en la que nos encontramos trabajando:

{% highlight posh%}
Get-EC2AvailabilityZone -Región us-east-1 | ft RegionName, Status, ZoneName
{% endhighlight %}

Creamos la subred con la información necesaria:

{% highlight posh%}
$subred = New-EC2Subnet -VpcId $vpc.VpcId -CidrBlock '10.0.1.0/24' AvailabilityZone 'us-east-1c'
{% endhighlight %}

Luego, registre la subred en la route table:

{% highlight posh%}
Register-EC2RouteTable -RouteTableId $routeTable.RouteTableId -SubnetId $subnet.SubnetId
{% endhighlight %}

### Crear la instancia EC2

La forma más fácil de crear una instancia EC2 es con Amazon Machine Images (AMI), permitiendo poner en marcha una máquina virtual con poco esfuerzo. Para ver las AMI que admite la región, debemos usar el comando `Get-SSMLatestEc2Image`.

A modo de ejemplo, para buscar imágenes Windows, podemos ejecutar:

{% highlight posh%}
Get-SSMLatestEC2Image -Path ami-windows-latest -Region us-east-1
{% endhighlight %}

<img src="/assets/images/postsImages/AWS_POSH_EC2_4.png" class="alignnone">

O podemos mirar las imágenes de Amazon Linux disponibles también:

{% highlight posh%}
Get-SSMLatestEC2Image -Path ami-amazon-linux-latest -Region us-east-1
{% endhighlight %}

Para este ejemplo, seleccionamos _Amazon Linux 2022_ con el kernel _5.15_:

{% highlight posh%}
$ami = Get-SSMLatestEC2Image -Path ami-amazon-linux-latest -Region us-east-1 -ImageName 'al2022-ami-minimal-kernel-5.15-x86_64'
{% endhighlight %}


Es posible filtrar por memoria y CPU. Como ejemplo, así es como puede encontrar cada tipo de instancia con un máximo de 4 GB de memoria y dos CPU:

{% highlight posh%}
Get-Ec2InstanceType -Region us-east-1 | `
  Select-Object InstanceType, @{Name = 'CPUs'; Expression = { $_.VCpuInfo.DefaultVCpus } }, `
  @{Name = 'MemoryGB'; Expression = { $_.MemoryInfo.SizeInMiB / 1024 } } | `
    Where-Object { $_.CPUs -lt 2 -and $_.MemoryGB -lt 4 } | `
    Sort-Object InstanceType | `
    Format-Table InstanceType,CPUs,MemoryGB
{% endhighlight %}


De la lista, seleccionamos **t2.micro**, que se encuentra en el _free tier_ de AWS. Con el tipo de instancia EC2 seleccionado, creamos la instancia EC2:

{% highlight posh%}
$newEC2Sparams = @{ 
  Region = 'us-east-1' 
    ImageId = $ami 
    AssociatePublicIp = $false 
    InstanceType = 't2.micro' 
    SubnetId = $subnet.SubnetId 
} 
New-Ec2Instance @newEC2Sparams
{% endhighlight %}

<img src="/assets/images/postsImages/AWS_POSH_EC2_5.png" class="alignnone">

Ahora, ya es posible encontrar la instancia con `Get-Ec2InstanceStatus`:

{% highlight posh%}
Get-Ec2InstanceStatus
{% endhighlight %}

<img src="/assets/images/postsImages/AWS_POSH_EC2_6.png" class="alignnone">

Para eliminar esa instancia, recupere el ID de la instancia con el comando anterior y luego use Remove-EC2Instance:

{% highlight posh%}
$instanceId = (Get-Ec2InstanceStatus).InstanceId
Remove-EC2Instance -InstanceId $instanceId -Region us-east-1
{% endhighlight %}


> Esto podemos hacerlo de esa manera ya que solo hay UNA ÚNICA instancia de EC2.

Ingresamos la letra "A" para confirmar todo y que proceda a eliminar la instancia creada anteriormente.

<img src="/assets/images/postsImages/AWS_POSH_EC2_7.png" class="alignnone">

Listo! Hemos borrado la instancia de EC2. Resta borrar el resto de los recursos o seguir explorando AWS hasta dominarlo!

Happy scripting!