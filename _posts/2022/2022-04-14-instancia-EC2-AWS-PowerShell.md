---
title: 'Crear una instancia de EC2 en AWS con PowerShell'
author: Victor Silva
date: 2022-04-14T01:03:56+00:00
layout: single
permalink: /instancia-EC2-AWS-PowerShell/
excerpt: ''
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


Con la CLI, los administradores pueden controlar los recursos de AWS desde la línea de comandos y escribir scripts de automatización. PowerShell también es una herramienta de línea de comandos, pero en comparación con AWS CLI , puede proporcionar algunas integraciones útiles y capacidades multiplataforma.

Siga este tutorial para obtener información sobre cómo iniciar una instancia EC2 mediante PowerShell, así como los requisitos previos y las dependencias necesarias.
Prerrequisitos locales

AWS tiene varios paquetes de PowerShell que puede usar para administrar su cuenta, como los siguientes:

    AWS.Herramientas. Una versión modularizada de AWS Tools for PowerShell. Esto se puede instalar en una computadora basada en Windows, así como en una computadora con Linux o macOS.
    AWSPowerShell.NetCore. La versión única de módulo grande de AWS Tools for PowerShell. Esto se puede instalar en una computadora basada en Windows, así como en una computadora con Linux o macOS.
    AWSPowerShell. La versión heredada, única y de módulo grande de Herramientas de AWS para PowerShell. Esto solo se puede instalar en una computadora basada en Windows.

En los siguientes ejemplos, usamos el módulo AWS.Tools en Windows. La principal ventaja de AWS.Tools es que no tiene que instalar todos los módulos de PowerShell para administrar su cuenta de AWS. Si bien esto agrega algo de complejidad, ya que debe planificar con anticipación para tener los módulos que necesita, le ahorra espacio y tiempo. Asegúrese de seguir también las instrucciones de requisitos previos para configurar su cuenta, el usuario de Identity and Access Management y las claves de acceso.

Instale los módulos necesarios con el siguiente comando:

Instalar-AWSToolsModule AWS.Tools.EC2,AWS.Tools.SimpleSystemsManagement

Si recibe un error que indica que el comando Install-AWSToolsModule no existe, asegúrese de haber instalado el módulo de instalación de AWS con lo siguiente:

Install-Module -Nombre AWS.Tools.Installer

Crea las dependencias

Antes de poder crear una instancia EC2, debe tener varios recursos ya creados. Si ya los tiene, haga referencia a los comandos Get- para recuperar los ID apropiados.

Para crear la configuración mínima para implementar y acceder a una instancia EC2, necesita una nube privada virtual ( VPC ) con una subred, algunos otros componentes de red y la propia instancia EC2.
Lanzar una VPC

Si ya tiene una VPC, busque el ID de VPC con el siguiente comando:

Get-EC2Vpc -Región us-west-2

Para crear una nueva VPC, primero defina una subred en la notación de enrutamiento entre dominios sin clase (CIDR):

$vpcCidr = '10.0.0.0/16'

Luego, cree la VPC con el comando New-EC2Vpc :

$vpc = Nuevo-EC2Vpc -CidrBlock $vpcCidr

Fuera de la caja, una AWS VPC no tiene ningún DNS configurado, por lo que debe habilitar el DNS en la VPC, que se transmite a cualquier instancia EC2 dentro de ella:

Editar-EC2VpcAttribute -VpcId $vpc.VpcId -EnableDnsSupport $true

Es posible que desee resolver públicamente los nombres de host de su instancia EC2. Puede habilitar eso con lo siguiente:

Edit-EC2VpcAttribute -VpcId $vpc.VpcId -EnableDnsHostnames $true

Implementar recursos de red

A continuación, debe agregar un par de recursos de red para garantizar que la nueva instancia EC2 tenga acceso a Internet y que pueda conectarse a ella. Estos recursos incluyen un gateway de Internet, una ruta a la tabla de rutas y una subred dentro de la subred de VPC.

Una puerta de enlace de Internet es lo que permite que una VPC se comunique con Internet. Primero, crea uno:

$internetGateway = New-EC2InternetGateway

Luego, asócielo a la VPC:

Add-EC2InternetGateway -InternetGatewayId $internetGateway.InternetGatewayId –VpcId $vpc.VpcId

Si desea que los nodos de la red, incluida la instancia EC2, sepan cómo enrutar a Internet, necesita una tabla de enrutamiento y una ruta. Cree la tabla de rutas y asóciela con la VPC:

$routeTable = New-EC2RouteTable -VpcId $vpc.VpcId

Luego, agréguele una ruta predeterminada:

New-EC2Route -GatewayId $internetGateway.InternetGatewayId -RouteTableId $routeTable.RouteTableId -DestinationCidrBlock '0.0.0.0/0'

Dado que la ruta predeterminada es la única ruta que está agregando a la tabla de rutas, todo el tráfico pasa por la puerta de enlace de Internet. Puede modificar esta regla o agregar más reglas. Las modificaciones son una mejor opción si desea tener más control sobre el tráfico que se envía a través de la puerta de enlace de Internet o si desea enrutar otro tráfico a otro lugar.

Para crear una subred dentro de la subred de la VPC, primero busque una zona de disponibilidad para crearla dentro de:

Get-EC2AvailabilityZone -Región us-west-2 | ft NombreRegión,Estado,NombreZona

Esto muestra todas las zonas en una Región. En este caso, hace referencia a la Región us-west-2 como se ve en la Figura 1:
Use un comando para ver las zonas de disponibilidad
Figura 1

Cree la subred:

$subred = New-EC2Subnet -VpcId $vpc.VpcId -CidrBlock '10.0.1.0/24' AvailabilityZone 'us-west-2a'

Luego, registre la subred con la tabla de enrutamiento:

Registro-EC2RouteTable -RouteTableId $routeTable.RouteTableId -SubnetId $subnet.SubnetId

Crear una instancia EC2

La forma más fácil de crear una instancia EC2 es con Amazon Machine Images ( AMI ). Estos le permiten poner en marcha una máquina virtual rápidamente. Para ver las AMI que admite la región, use Get-SSMLatestEc2Image . Si desea encontrar imágenes de Windows, puede hacerlo con lo siguiente:

Get-SSMLatestEC2Image -Path ami-windows-latest -Region us-west-2

O puede mirar las imágenes de Linux:

Get-SSMLatestEC2Image -Path ami-amazon-linux-latest -Region us-west-2

De la lista, seleccione la imagen que se ajuste a sus necesidades. Para este ejemplo, seleccionamos Linux 2022 de Amazon con el kernel 5.15:

$ami = Get-SSMLatestEC2Image -Path ami-amazon-linux-latest -Region us-west-2 -ImageName 'al2022-ami-minimal-kernel-5.15-x86_64'

Para seleccionar un tipo de instancia EC2, use el comando Get-Ec2InstanceType . Obtienes mucha producción. Por ejemplo, en la figura 2, la región us-west-2 tiene 506 tipos de instancias:
Comando Get-Ec2InstanceType
Figura 2

Puede filtrar por memoria y CPU. Como ejemplo, así es como puede encontrar cada tipo de instancia con un máximo de 4 GB de memoria y dos CPU:

Get-Ec2InstanceType -Región us-west-2 | ` 
    Tipo de instancia de objeto seleccionado, @{Nombre = 'CPU'; Expresión = { $_.VCpuInfo.DefaultVCpus } } ` 
    @{Nombre = 'MemoryGB'; Expresión = { $_.MemoryInfo.SizeInMiB / 1024 } } | ` 
        Where-Object { $_.CPUs -le 2 -and $_.MemoryGB -le 4 } | ` 
            Ordenar tipo de instancia de objeto | ` 
                Formato-Tabla InstanceType,CPUs,MemoryGB

Para ajustar ese comando a sus necesidades específicas de recursos, cambie la expresión Where-Object .

El comando tiene una salida simplificada que se parece a la Figura 3:
Salida simplificada para instancias EC2
figura 3

De la lista, seleccione t2.micro, que se encuentra en el nivel gratuito de AWS. Con el tipo de instancia EC2 seleccionado, cree la instancia EC2:

{% highlight posh%}

$newEC2Splat = @{ 
  Region = 'us-west-2' 
    ImageId = $ami 
    AssociatePublicIp = $false 
    InstanceType = 't2.micro' 
    SubnetId = $subnet.SubnetId 
} 
New-Ec2Instance @newEC2Splat
{% endhighlight %}

El resultado es similar a la Figura 4:
Salida en PowerShell después de crear una instancia EC2
Figura 4

Ahora, puede encontrar la instancia con Get-Ec2InstanceStatus , que se muestra en la Figura 5:
Encuentre la instancia con Get-Ec2InstanceStatus
Figura 5

Para eliminar esa instancia, recupere el ID de la instancia con el comando anterior y luego use Remove-EC2Instance :

Remove-EC2Instance -InstanceId i-0b684c72317a9e9d2 -Región us-west-2

Se le pide confirmación y ve un objeto que resume los estados modificados, como en la Figura 6:
Estado resumido de PowerShell
Figura 6

